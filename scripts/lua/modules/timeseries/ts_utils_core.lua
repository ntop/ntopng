--
-- (C) 2018-24 - ntop.org
--

-- #################################

local ts_utils = {}

local ts_common = require "ts_common"

ts_utils.metrics = ts_common.metrics
ts_utils.aggregation = ts_common.aggregation
ts_utils.schema = require "ts_schema"
ts_utils.getLastError = ts_common.getLastError
ts_utils.getLastErrorMessage = ts_common.getLastErrorMessage
ts_utils.custom_schemas = {}

-- This is used in realtime charts to avoid querying recent data not written to
-- the database yet.
-- See also CONST_INFLUXDB_FLUSH_TIME
ts_utils.MAX_EXPORT_TIME = 60

require "lua_trace"
require "ntop_utils"

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/schemas/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/custom/?.lua;" .. package.path

-- ##############################################

local loaded_schemas = {}

-- ! @brief Define a new timeseries schema.
-- ! @param name the schema identifier.
-- ! @return the newly created schema.
function ts_utils.newSchema(name, options)
    local schema = ts_utils.schema:new(name, options)

    if loaded_schemas[name] ~= nil then
        traceError(TRACE_WARNING, TRACE_CONSOLE, "Schema already defined: " .. name)
        return loaded_schemas[name]
    end

    loaded_schemas[name] = schema

    return schema
end

-- ##############################################

-- ! @brief Find schema by name.
-- ! @param name the schema identifier.
-- ! @return a schema object on success, nil on error.
function ts_utils.getSchema(name)
    local schema = loaded_schemas[name]

    if schema then
        -- insertion_step: this corresponds to the interval of data writes
        -- step: used for visualization
        schema.options.insertion_step = schema.options.step
    end

    if schema and hasHighResolutionTs() then
        if ((schema.options.step == 300) and (schema.options.is_system_schema ~= true)) then
            schema.options.insertion_step = 60
            schema.options.step = 60
        end
    end

    if schema and (name == "iface:traffic") and ntop.isnEdge() then
        schema.options.step = 4
    end

    if schema then
        if not interface.isPacketInterface() then
            -- For non-packet interfaces it is necessary to adjust the
            -- step used when READING to make sure no timeseries will
            -- be read at a resolution higher than the interface.getStatsUpdateFreq.
            -- The rationale is that if a ZMQ sends you flows with a timeout of 2 minutes
            -- it is pointless to look at a resolution lower than these 2 minutes.
            -- For packet interfaces the story is different. In this case ntopng sees
            -- the traffic on a packet-by-packet basis so we can leave the step untouched
            -- and go at the highest po
            local update_freq = interface.getStatsUpdateFreq()

            if update_freq then
                if schema.options.step < update_freq then
                    schema.options.step = update_freq
                end
            end
        end
    end

    return schema
end

function ts_utils.loadSchemas()
    local script_manager = require("script_manager")

    -- This should include all the available schemas
    require("ts_second")
    require("ts_minute")
    require("ts_5min")
    require("ts_5sec")
    require("ts_hour")

    -- Possibly load more timeseries schemas
    script_manager.loadSchemas()

    if (ntop.exists(dirs.installdir .. "/scripts/lua/modules/timeseries/custom/ts_minute_custom.lua")) then
        require("ts_minute_custom")
    end

    if (ntop.exists(dirs.installdir .. "/scripts/lua/modules/timeseries/custom/ts_5min_custom.lua")) then
        require("ts_5min_custom")
    end
end

function ts_utils.getLoadedSchemas()
    return loaded_schemas
end

-- ##############################################

local cached_active_drivers = nil

-- ! @brief Return a list of active timeseries drivers.
-- ! @return list of driver objects.
function ts_utils.listActiveDrivers()
    if cached_active_drivers ~= nil then
        return cached_active_drivers
    end

    local driver = ts_utils.getDriverName()
    local active_drivers = {}

    if driver == "rrd" then
        local dirs = ntop.getDirs()
        local rrd_driver = require("rrd"):new({
            base_path = (dirs.workingdir .. "/rrd_new")
        })
        active_drivers[#active_drivers + 1] = rrd_driver
    elseif driver == "influxdb" then
        local auth_enabled = (ntop.getPref("ntopng.prefs.influx_auth_enabled") == "1")

        local influxdb_driver = require("influxdb"):new({
            url = ntop.getPref("ntopng.prefs.ts_post_data_url"),
            db = ntop.getPref("ntopng.prefs.influx_dbname"),
            username = ternary(auth_enabled, ntop.getPref("ntopng.prefs.influx_username"), nil),
            password = ternary(auth_enabled, ntop.getPref("ntopng.prefs.influx_password"), nil)
        })
        active_drivers[#active_drivers + 1] = influxdb_driver
    end

    -- cache for future calls
    cached_active_drivers = active_drivers

    return active_drivers
end

-- ##############################################

-- Get the driver to use to query data
function ts_utils.getQueryDriver()
    local drivers = ts_utils.listActiveDrivers()

    -- NOTE: prefer the InfluxDB driver if available, RRD as fallback
    local driver = drivers[2] or drivers[1]

    return driver
end

-- ##############################################

function ts_utils.getDriverName()
    local driver = ntop.getPref("ntopng.prefs.timeseries_driver")

    if isEmptyString(driver) then
        driver = "rrd"
    end

    return driver
end

-- ##############################################

local function isUserAccessAllowed(tags)
    local user = _SESSION and _SESSION["user"] or ""

    if(user == "admin") then
       return true
    end
    
    if tags.ifid and not ntop.isnEdge()
       and not ntop.isAllowedInterface(tonumber(tags.ifid)) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "User: " .. user .. " is not allowed to access interface " .. tags.ifid)
        return false
    end

    -- Note: tags.host can contain a MAC address for local broadcast domain hosts
    local host = tags.host_ip or tags.host
    if host and not ntop.isAllowedNetwork(host) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "User: " .. user .. " is not allowed to access host " .. host)
        return false
    end

    if tags.subnet and not ntop.isAllowedNetwork(tags.subnet) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "User: " .. user .. " is not allowed to access subnet " .. tags.subnet)
        return false
    end

    return true
end

-- ##############################################

-- ! @brief Append a new data point to the specified timeseries.
-- ! @param schema_name the schema identifier.
-- ! @param tags_and_metrics a table with tag->value and metric->value mappings.
-- ! @param timestamp the timestamp associated with the data point.
-- ! @return true on success, false on error.
function ts_utils.append(schema_name, tags_and_metrics, timestamp)
    timestamp = timestamp or os.time()
    local schema = ts_utils.getSchema(schema_name)

    if not schema then
        tprint(debug.traceback())
        traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
        return false
    end

    local tags, data = schema:verifyTagsAndMetrics(tags_and_metrics)

    if not tags then
        return false
    end

    if not schema.options.is_critical_ts and ntop.isDeadlineApproaching() then
        -- Do not write timeseries if the deadline is approaching.
        -- traceError(TRACE_NORMAL, TRACE_CONSOLE, "Deadline approaching... [".. schema.name .."]["..formatEpoch(ntop.getDeadline()).."]")
        return false
    else
        -- require "lua_utils"
        -- traceError(TRACE_NORMAL, TRACE_CONSOLE, "Deadline OK ... [".. schema.name .."]["..formatEpoch(ntop.getDeadline()).."]")
    end

    local rv = true

    -- traceError(TRACE_NORMAL, TRACE_CONSOLE, "TS.UPDATE [".. schema.name .."] " .. table.tconcat(tags_and_metrics, "=", ","))

    ts_common.clearLastError()

    for _, driver in pairs(ts_utils.listActiveDrivers()) do
        rv = driver:append(schema, timestamp, tags, data) and rv
    end

    return rv
end

-- ##############################################

-- Get some default options to use in queries.
function ts_utils.getQueryOptions(overrides)
    return table.merge({
        min_num_points = 0, -- maximum number of points per data serie
        max_num_points = 80, -- maximum number of points per data serie
        fill_value = 0 / 0, -- e.g. 0/0 for nan
        min_value = 0, -- minimum value of a data point
        max_value = math.huge, -- maximum value for a data point
        top = 8, -- top number of items
        calculate_stats = true, -- calculate stats if possible
        initial_point = false, -- add an extra initial point, not accounted in statistics but useful for drawing graphs
        no_timeout = true, -- do not abort queries automatically by default
        fill_series = false, -- if true, filling missing points is required
        keep_nan = false
    }, overrides or {})
end

-- ##############################################

-- ! @brief Perform a query to extract timeseries data.
-- ! @param schema_name the schema identifier.
-- ! @param tags a list of filter tags. All the tags for the given schema must be specified.
-- ! @param tstart lower time for the query.
-- ! @param tend upper time for the query.
-- ! @param options (optional) query options.
-- ! @return query result on success, nil on error.
function ts_utils.query(schema_name, tags, tstart, tend, options)
    if not isUserAccessAllowed(tags) then
        return nil
    end

    local query_options = ts_utils.getQueryOptions(options)
    local schema = ts_utils.getSchema(schema_name)

    if not schema then
        -- traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
        return nil
    end

    local actual_tags = schema:verifyTags(tags)

    if not actual_tags then
        return nil
    end

    local driver = ts_utils.getQueryDriver()

    if not driver then
        return nil
    end

    ts_common.clearLastError()

    local rv = driver:query(schema, tstart, tend, actual_tags, query_options)

    if rv == nil then
        return nil
    end

    rv["end"] = tend

    -- Add tags information for consistency with timeseries_top
    for _, serie in pairs(rv.series) do
        serie.tags = actual_tags
    end

    return rv
end

-- ##############################################

function ts_utils.timeseries_query(options)
    if not isUserAccessAllowed(options.tags) then
        return nil
    end

    options = ts_utils.getQueryOptions(options)
    options.schema_info = ts_utils.getSchema(options.schema)

    if not options.schema_info then
        -- traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
        return nil
    end

    local actual_tags = options.schema_info:verifyTags(options.tags)

    if not actual_tags then
        return nil
    end

    local driver = ts_utils.getQueryDriver()

    if not driver then
        return nil
    end

    ts_common.clearLastError()

    local rv = driver:timeseries_query(options)

    if rv == nil then
        return nil
    end

    return rv
end

-- ##############################################

local function get_top_talkers(schema_id, tags, tstart, tend, options)
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
    local top_utils = require "top_utils"
    local num_minutes = math.floor((tend - tstart) / 60)
    local top_talkers = top_utils.getAggregatedTop(getInterfaceName(ifId), tend, num_minutes)
    local top_series = {}
    local top_hosts = {}
    local direction = nil
    local select_col = nil
    local step = 0
    local count = 0

    if schema_id == "local_senders" then
        direction = "senders"
        select_col = "sent"
    else
        direction = "receivers"
        select_col = "rcvd"
    end

    for _, vlan in pairs(top_talkers.vlan or {}) do
        for _, host in pairs(vlan.hosts[1][direction] or {}) do
            -- need to recalculate total value
            local host_tags = {
                ifid = tags.ifid,
                host = host.address
            }
            local host_options = ts_utils.getQueryOptions({
                schema = "host:traffic",
                epoch_begin = tstart,
                epoch_end = tend,
                tags = host_tags
            })
            local host_partials = ts_utils.timeseries_query(host_options) or {}
            local data_direction = ternary(direction == "senders", "bytes_sent", "bytes_rcvd")

            if not table.empty(host_partials) then
                for _, timeseries_info in pairs(host_partials.series) do
                    if timeseries_info.id == data_direction then
                        host_partials = timeseries_info
                        top_hosts[host.address] = timeseries_info.statistics.total or 0
                        break
                    end
                end

                top_series[host.address] = table.merge({
                    tags = host_tags,
                    meta = {
                        url = host.url,
                        label = host.label,
                        ipaddr = host.ipaddr, -- optional
                        visual_addr = host.visual_addr -- optional
                    }
                }, host_partials)
            end
        end
    end

    local res = {}
    for host, _ in pairsByValues(top_hosts, rev) do
        res[#res + 1] = top_series[host]

        if #res >= options.top then
            break
        end
    end

    return {
        metadata = {
            epoch_begin = options.epoch_begin,
            epoch_end = options.epoch_end,
            epoch_step = step,
            num_point = count,
            schema = options.schema,
            query = options.tags
        },
        series = res
    }
end

-- A bunch of pre-computed top items functions
-- Must return in the same format as driver:timeseries_top
local function getPrecomputedTops(schema_id, tags, tstart, tend, options)
    if (schema_id == "local_senders") or (schema_id == "local_receivers") then
        return get_top_talkers(schema_id, tags, tstart, tend, options)
    end

    return nil
end

-- ##############################################

-- ! @brief Perform a top query.
-- ! @param options contains all the info available of the timeseries
--                  from the schema to the timeframe, options, ecc.
function ts_utils.timeseries_query_top(options)
    options = ts_utils.getQueryOptions(options)
    local top_items = nil
    local schema = nil

    if not isUserAccessAllowed(options.tags) then
        return nil
    end

    local driver = ts_utils.getQueryDriver()

    if not driver then
        return nil
    end

    ts_common.clearLastError()

    -- Check if some tops are already pre-computed
    local pre_computed = getPrecomputedTops(options.schema, options.tags, options.epoch_begin, options.epoch_end,
        options)

    if pre_computed then
        -- Use precomputed top items
        top_items = pre_computed
        schema = pre_computed.schema
    else
        options.schema_info = ts_utils.getSchema(options.schema)

        if not options.schema_info then
            traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. options.schema)
            return nil
        end

        local top_tags = {}

        for _, tag in ipairs(options.schema_info._tags) do
            if not options.tags[tag] then
                top_tags[#top_tags + 1] = tag
            end
        end

        -- options.rrdfile means that a single query is requested
        if table.empty(top_tags) then
            -- no top tags, just a plain query
            return ts_utils.timeseries_query(options)
        end

        -- Find the top items
        local topk_heuristic = ntop.getPref("ntopng.prefs.topk_heuristic_precision")
        if (topk_heuristic ~= 'disabled') then
            top_items = driver:timeseries_top(options, top_tags)
        end
    end

    return top_items
end

-- ##############################################

local function getWildcardTags(schema, tags_filter)
    tags_filter = tags_filter or {}

    local wildcard_tags = {}
    local filter_tags = {}

    for tag in pairs(schema.tags) do
        if not tags_filter[tag] then
            wildcard_tags[#wildcard_tags + 1] = tag
        end
    end

    -- only pass schema own tags
    for tag, val in pairs(tags_filter) do
        if schema.tags[tag] then
            filter_tags[tag] = val
        end
    end

    return filter_tags, wildcard_tags
end

-- ##############################################

-- ! @brief List all available timeseries for the specified schema, tags and time.
-- ! @param schema_name the schema identifier.
-- ! @param tags_filter a list of filter tags. Tags which are not specified are considered wildcard.
-- ! @param start_time time filter. Only timeseries updated after start_time will be returned.
-- ! @param end_time time filter. Only timeseries updated before end_time will be returned.
-- ! @return a (possibly empty) list of tags values for the matching timeseries on success, nil on error.
function ts_utils.listSeries(schema_name, tags_filter, start_time, end_time, not_print_error)
    local schema = ts_utils.getSchema(schema_name)
    local driver = ts_utils.getQueryDriver()

    if (not schema) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
        return nil
    end

    if (not driver) then
        return nil
    end

    local filter_tags, wildcard_tags = getWildcardTags(schema, tags_filter)

    return driver:listSeries(schema, filter_tags, wildcard_tags, start_time, end_time, not_print_error)

end

-- ##############################################

local pending_listseries_batch = {}

-- ! @brief Add a listSeries request to the current batch.
-- ! @param schema_name the schema identifier.
-- ! @param tags_filter a list of filter tags. Tags which are not specified are considered wildcard.
-- ! @param start_time time filter. Only timeseries updated after start_time will be returned.
-- ! @return nil on error, otherwise a number is returned, indicating the item id into the batch
-- ! @note Call ts_utils.getBatchedListSeriesResult() to get the batch responses
function ts_utils.batchListSeries(schema_name, tags_filter, start_time)
    local schema = ts_utils.getSchema(schema_name)

    if (not schema) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
        return nil
    end

    local filter_tags, wildcard_tags = getWildcardTags(schema, tags_filter)

    pending_listseries_batch[#pending_listseries_batch + 1] = {
        schema = schema,
        start_time = start_time,
        tags = tags_filter,
        filter_tags = filter_tags,
        wildcard_tags = wildcard_tags
    }

    -- return id in batch
    return #pending_listseries_batch
end

-- ##############################################

-- ! @brief Completes the current batched requests and returns the results.
-- ! @return nil on error, otherwise a table item_id -> result is returned. See ts_utils.listSeries() for details.
function ts_utils.getBatchedListSeriesResult()
    local driver = ts_utils.getQueryDriver()
    local result

    if not driver then
        return nil
    end

    ts_common.clearLastError()

    if (driver.listSeriesBatched == nil) then
        -- Do not batch, just call listSeries
        result = {}

        for key, item in pairs(pending_listseries_batch) do
            result[key] = driver:listSeries(item.schema, item.filter_tags, item.wildcard_tags, item.start_time,
                item.end_time or nil)
        end
    else
        result = driver:listSeriesBatched(pending_listseries_batch)
    end

    pending_listseries_batch = {}

    return result
end

-- ##############################################

-- ! @brief Verify timeseries existance.
-- ! @param schema_name the schema identifier.
-- ! @param tags_filter a list of filter tags. Tags which are not specified are considered wildcard.
-- ! @return true if the specified series exist, false otherwise.
function ts_utils.exists(schema_name, tags_filter)
    local driver = ts_utils.getQueryDriver()

    if not driver then
        return nil
    end

    if (driver.exists == nil) then
        -- No "exists" implementation found, use listSeries fallback
        return not table.empty(ts_utils.listSeries(schema_name, tags_filter, 0))
    end

    local schema = ts_utils.getSchema(schema_name)

    if (not schema) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
        return nil
    end

    local filter_tags, wildcard_tags = getWildcardTags(schema, tags_filter)
    return driver:exists(schema, filter_tags, wildcard_tags)
end

-- ##############################################

-- ! @brief Delete timeseries data.
-- ! @param schema_prefix a prefix for the schemas.
-- ! @param tags a list of filter tags.
-- ! @return true if operation was successful, false otherwise.
-- ! @note E.g. "iface" schema_prefix matches any schema starting with "iface:". Empty prefix is allowed and matches all the schemas.
function ts_utils.delete(schema_prefix, tags)
    if not isAdministrator() then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "Not Admin")
        return false
    end

    if not isUserAccessAllowed(tags) then
        return false
    end

    if string.find(schema_prefix, ":") ~= nil then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "Full schema labels not supported, use schema prefixes instead.")
        return false
    end

    local rv = true

    ts_common.clearLastError()

    for _, driver in pairs(ts_utils.listActiveDrivers()) do
        rv = driver:delete(schema_prefix, tags) and rv
    end

    return rv
end

-- ##############################################

-- ! @brief Delete old data.
-- ! @param ifid: the interface ID to process
-- ! @return true if operation was successful, false otherwise.
function ts_utils.deleteOldData(ifid)
    if not isAdministrator() then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "Not Admin")
        return false
    end

    ts_common.clearLastError()

    for _, driver in pairs(ts_utils.listActiveDrivers()) do
        rv = driver:deleteOldData(ifid) and rv
    end

    return rv
end

-- ##############################################

function ts_utils.queryTotal(schema_name, tstart, tend, tags, options)
    if not isUserAccessAllowed(tags) then
        return nil
    end

    local schema = ts_utils.getSchema(schema_name)

    if not schema then
        if print_error then
            traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
        end
        return nil
    end

    local driver = ts_utils.getQueryDriver()

    if not driver or not driver.queryTotal then
        return nil
    end

    local query_options = ts_utils.getQueryOptions(options)

    ts_common.clearLastError()

    return driver:queryTotal(schema, tstart, tend, tags, query_options)
end

-- ##############################################

function ts_utils.queryLastValues(schema_name, tstart, tend, tags, options)
    if not isUserAccessAllowed(tags) then
        return nil
    end

    local options = ts_utils.getQueryOptions(options)

    options.tags = tags
    options.epoch_begin = tstart
    options.epoch_end = tend
    options.schema_info = ts_utils.getSchema(schema_name)

    if not options.schema_info then
        if print_error then
            traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
        end
        return nil
    end

    local actual_tags = options.schema_info:verifyTags(options.tags)

    if not actual_tags then
        return nil
    end

    local driver = ts_utils.getQueryDriver()

    if not driver or not driver.queryLastValues then
        return nil
    end

    ts_common.clearLastError()

    return driver:queryLastValues(options)
end

-- ##############################################

function ts_utils.queryMean(schema_name, tstart, tend, tags, options)
    if not isUserAccessAllowed(tags) then
        return nil
    end

    local schema = ts_utils.getSchema(schema_name)

    if not schema then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
        return nil
    end

    local query_options = ts_utils.getQueryOptions(options)

    local rv = ts_utils.queryTotal(schema_name, tstart, tend, tags, query_options)
    local intervals = math.floor((tend - tstart) / schema.options.step)

    for i, total in pairs(rv or {}) do
        rv[i] = total / intervals
    end

    return rv
end

-- ##############################################

local SETUP_OK_KEY = "ntopng.cache.ts_setup_ok"

function ts_utils.setupAgain()
    -- will run the setup again
    ntop.delCache(SETUP_OK_KEY)
end

-- ##############################################

function ts_utils.setup()
    local setup_ok = ntop.getPref(SETUP_OK_KEY)

    if (ntop.getCache(SETUP_OK_KEY) ~= "1") then
        if ts_utils.getQueryDriver():setup(ts_utils) then
            -- success, update version
            ntop.setCache(SETUP_OK_KEY, "1")
            return true
        end

        return false
    end

    return true
end

-- ##############################################

-- ! @brief Get a list of existing schemas which have possibly changed format
-- ! @return a table with a list of possibly changed schemas
-- ! @note This function should be updated whenever an existng schema is changed
function ts_utils.getPossiblyChangedSchemas()
    return { -- Interface timeseries
    "iface:alerted_flows", "iface:score", "iface:score_behavior_v2", "iface:score_anomalies_v2",
    "iface:traffic_anomalies_v2", "iface:traffic_rx_behavior_v5", "iface:traffic_tx_behavior_v5",
    "iface:engaged_alerts", "iface:local_hosts", "subnet:score_anomalies", "subnet:intranet_traffic",
    "subnet:intranet_traffic_min", "host:contacts", -- split in "as_client" and "as_server"
    "sflowdev_port:usage", "flowdev_port:usage", "snmp_if:usage", "host:score", -- split in "cli_score" and "srv_score"
    "host:contacts_behaviour", "host:cli_active_flows_behaviour", "host:srv_active_flows_behaviour",
    "host:cli_score_behaviour", "host:srv_score_behaviour", "host:cli_active_flows_anomalies",
    "host:srv_active_flows_anomalies", "host:cli_score_anomalies", "host:srv_score_anomalies", "host:ndpi_categories", -- split in "bytes_sent" and "bytes_rcvd"
    "host:tcp_rx_stats", "host:udp_sent_unicast", "host:dns_qry_rcvd_rsp_sent", "host:dns_qry_sent_rsp_rcvd",
    "host:tcp_tx_stats", "iface:hosts_anomalies", -- Added missing ifid tag
    "influxdb:storage_size", "influxdb:exported_points", "influxdb:exports", "influxdb:rtt", "system:cpu_load",
    "process:resident_memory", "redis:keys", "redis:memory", "periodic_script:timeseries_writes",
    "mac:arp_rqst_sent_rcvd_rpls", -- Active Monitoring
    "am_host:http_stats_min", "am_host:https_stats_min", "am_host:val_min", "am_host:http_stats_5mins",
    "am_host:https_stats_5mins", "am_host:val_5mins", "am_host:http_stats_hour", "am_host:https_stats_hour",
    "am_host:val_hour", "snmp_if:cbqos" }
end

-- ##############################################

function ts_utils.get_memory_size_query(influxdb, schema, tstart, tend, time_step)
    --[[
      See comments in function driver:getMemoryUsage() to understand
      why it is necessary to subtract the HeapReleased from Sys.
   --]]
    local q = 'SELECT MEAN(Sys) - MEAN(HeapReleased) as mem_bytes' .. ' FROM "_internal".."runtime"' ..
                  " WHERE time >= " .. tstart .. "000000000 AND time <= " .. tend .. "000000000" .. " GROUP BY TIME(" ..
                  time_step .. "s)"

    return (q)
end

-- ##############################################

function ts_utils.get_write_success_query(influxdb, schema, tstart, tend, time_step)
    local q = 'SELECT SUM(writePointsOk) as points' .. ' FROM (SELECT ' .. ' (DERIVATIVE(MEAN(writePointsOk)) / ' ..
                  time_step .. ') as writePointsOk' .. ' FROM "monitor"."shard" WHERE "database"=\'' .. influxdb.db ..
                  '\'' .. " AND time >= " .. tstart .. "000000000 AND time <= " .. tend .. "000000000" ..
                  " GROUP BY id)" .. " GROUP BY TIME(" .. time_step .. "s)"

    return (q)
end

-- ##############################################

-- This function return a table of options used by timeseries
function ts_utils.get_stats_options(basic_options)
    return {
        calculate_stats = true,
        top = 30, -- this is higher to calculate the totals
        tags = basic_options.tags,
        schema = basic_options.ts_schema,
        epoch_begin = basic_options.epoch_begin,
        epoch_end = basic_options.epoch_end,
        initial_point = false,
        with_series = true,
        keep_nan = false
    }
end

-- ##############################################

return ts_utils
