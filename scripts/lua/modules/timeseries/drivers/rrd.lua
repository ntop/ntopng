--
-- (C) 2020-24 - ntop.org
--
local driver = {}

local os_utils = require("os_utils")
local ts_common = require("ts_common")

require("rrd_paths")

local use_hwpredict = false
local use_rrd_queue = true

local type_to_rrdtype = {
    [ts_common.metrics.counter] = "DERIVE",
    [ts_common.metrics.gauge] = "GAUGE"
}

local aggregation_to_consolidation = {
    [ts_common.aggregation.mean] = "AVERAGE",
    [ts_common.aggregation.max] = "MAX",
    [ts_common.aggregation.min] = "MIN",
    [ts_common.aggregation.last] = "LAST"
}

local L4_PROTO_KEYS = {
    tcp = 6,
    udp = 17,
    icmp = 1,
    eigrp = 88,
    other_ip = -1
}

-- ##############################################

local debug_enabled = nil
local function isDebugEnabled()
    if debug_enabled == nil then
        -- cache it
        debug_enabled = (ntop.getPref("ntopng.prefs.rrd_debug_enabled") == "1")
    end

    return (debug_enabled)
end

-- ##############################################

function driver:new(options)
    local obj = {
        base_path = options.base_path
    }

    setmetatable(obj, self)
    self.__index = self

    return obj
end

-- ##############################################

function driver:getLatestTimestamp(ifid)
    return os.time()
end

-- ##############################################

-- Maps second tag name to getRRDName
local HOST_PREFIX_MAP = {
    host = "",
    mac = "",
    subnet = "net:",
    flowdev_port = "flow_device:",
    sflowdev_port = "sflow:",
    snmp_if = "snmp:",
    host_pool = "pool:"
}
local WILDCARD_TAGS = {
    protocol = 1,
    category = 1,
    l4proto = 1,
    dscp_class = 1
}

local function get_fname_for_schema(schema, tags)
    if schema.options.rrd_fname ~= nil then
        return schema.options.rrd_fname
    end

    local last_tag = schema._tags[#schema._tags]

    if WILDCARD_TAGS[last_tag] then
        -- return the last defined tag
        return tags[last_tag]
    end

    -- e.g. host:contacts -> contacts
    local suffix = string.split(schema.name, ":")[2]
    return suffix
end

local function schema_get_path(schema, tags)
    local parts = {schema.name}
    local suffix = ""
    local rrd

    -- ifid is mandatory here
    local ifid = tags.ifid or -1
    local host_or_network = nil
    local parts = string.split(schema.name, ":")

    if ((string.find(schema.name, "iface:") ~= 1) and -- interfaces are only identified by the first tag
    (#schema._tags >= 1)) then -- some schema do not have any tag, e.g. "process:*" schemas
        local prefix = HOST_PREFIX_MAP[parts[1]] or (parts[1] .. ":")
        local suffix = tags[schema._tags[2] or schema._tags[1]] or tags[schema._tags[1]]

        if (suffix ~= ifid) then
            host_or_network = prefix .. suffix
        else
            -- Avoid repeating the ifid suffix in the path
            host_or_network = prefix .. ""
        end
    end

    -- Some exceptions to avoid conflicts / keep compatibility
    if parts[1] == "snmp_if" then
        if tags.qos_class_id then
            suffix = tags.if_index .. "/" .. tags.qos_class_id .. "/"
        else
            suffix = tags.if_index .. "/"
        end
    elseif (parts[1] == "flowdev_port") or (parts[1] == "sflowdev_port") then
        if (tags.port) then
            if (type(tags.port) == "table") then
                suffix = tags.port.ifindex .. "/"
            else
                suffix = tags.port .. "/"
            end
        elseif (tags.ifid) then
            suffix = tags.ifid .. "/"
        else
            suffix = tags.port.ifindex .. "/"
        end
    elseif #schema._tags >= 3 then
        local intermediate_tags = {}

        -- tag1:ifid
        -- tag2:already handled as host_or_network
        -- last tag must be handled separately
        for i = 3, #schema._tags - 1 do
            intermediate_tags[#intermediate_tags + 1] = tags[schema._tags[i]]
        end

        local last_tag = schema._tags[#schema._tags]

        if (not WILDCARD_TAGS[last_tag]) then
            intermediate_tags[#intermediate_tags + 1] = tags[last_tag]
        end

        if intermediate_tags[1] ~= nil then
            -- All the intermediate tags should be mapped in the path
            suffix = table.concat(intermediate_tags, "/") .. "/"
        end

        if parts[2] == "ndpi_categories" then
            suffix = suffix .. "ndpi_categories/"
        elseif parts[2] == "ndpi_flows" then
            suffix = suffix .. "ndpi_flows/"
        elseif parts[2] == "l4protos" then
            suffix = suffix .. "l4protos/"
        elseif parts[2] == "dscp" then
            suffix = suffix .. "dscp/"
        end

    elseif parts[2] == "ndpi_categories" then
        suffix = "ndpi_categories/"
    elseif parts[2] == "ndpi_flows" then
        suffix = "ndpi_flows/"
    elseif parts[2] == "l4protos" then
        suffix = "l4protos/"
    elseif parts[2] == "dscp" then
        suffix = "dscp/"
    end

    local path = getRRDName(ifid, host_or_network) .. suffix
    local rrd = get_fname_for_schema(schema, tags)

    return path, rrd
end

function driver.schema_get_full_path(schema, tags)
    local base, rrd = schema_get_path(schema, tags)

    if ((not base) or (not rrd)) then
        return nil
    end

    local full_path = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

    return full_path
end

-- ##############################################

local function getRRAParameters(step, resolution, retention_time)
    local aggregation_dp = math.ceil(resolution / step)
    local retention_dp = math.ceil(retention_time / resolution)
    return aggregation_dp, retention_dp
end

-- ##############################################

local function getConsolidationFunction(schema)
    local fn = schema:getAggregationFunction()

    if (aggregation_to_consolidation[fn] ~= nil) then
        return (aggregation_to_consolidation[fn])
    end

    traceError(TRACE_ERROR, TRACE_CONSOLE, "unknown aggregation function: %s", fn)

    return ("AVERAGE")
end

-- ##############################################

local function create_rrd(schema, path, timestamp)
    local heartbeat = schema.options.rrd_heartbeat or (schema.options.insertion_step * 2)
    local rrd_type = type_to_rrdtype[schema.options.metrics_type]
    local params = {path, schema.options.insertion_step}
    local cf = getConsolidationFunction(schema)

    if (timestamp ~= nil) then
        -- RRD start time (--start/-b)
        -- It must be tuned so that the first point of the chart in the subsequent
        -- rrd_update will not be discarded
        params[#params + 1] = timestamp - schema.options.insertion_step
    end

    for idx, metric in ipairs(schema._metrics) do
        params[#params + 1] = "DS:" .. metric .. ":" .. rrd_type .. ':' .. heartbeat .. ':U:U'
    end

    for _, rra in ipairs(schema.retention) do
        params[#params + 1] = "RRA:" .. cf .. ":0.5:" .. rra.aggregation_dp .. ":" .. rra.retention_dp
    end

    if use_hwpredict and schema.hwpredict then
        -- NOTE: at most one RRA, otherwise rrd_update crashes.
        local hwpredict = schema.hwpredict
        params[#params + 1] = "RRA:HWPREDICT:" .. hwpredict.row_count .. ":0.1:0.0035:" .. hwpredict.period
    end

    if isDebugEnabled() then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("ntop.rrd_create(%s) schema=%s", table.concat(params, ", "), schema.name))
    end

    local err = ntop.rrd_create(table.unpack(params))
    if (err ~= nil) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, err)
        return false
    end

    return true
end

-- ###############################################

-- Converts a number (either decimal or integer) to a string
-- in a format which is friendly for the subsequent call to rrd_update
local function number_to_rrd_string(what, schema)
    local schema_name = schema and schema.name or 'unknown'
    local err_msg = ''
    what = tonumber(what)

    if (what == nil) then
        err_msg = "Attempting at converting a nil to number"
    elseif (type(what) ~= "number") then
        err_msg = "number_to_rrd_string got a non-number argument: " .. type(what)
    elseif (what ~= what) then
        err_msg = "Trying to convert NaN to integer"
    elseif (what == math.huge) then
        err_msg = "Trying to convert inf to integer"
    elseif (math.maxinteger and ((what >= math.maxinteger) or (what <= math.mininteger))) then
        err_msg = "Number out of integers range: " .. what
    elseif what == math.floor(what) then
        -- If the number has no decimal place, print it as a digit
        return (string.format("%d", what))
    else
        -- If the number has decimal places, print it as a float
        -- (don't touch the precision, let's the rrd do this job if necessary)
        return (string.format("%f", what))
    end

    -- Log the error with the schema name
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("%s [%s]", err_msg, schema_name))
    traceError(TRACE_ERROR, TRACE_CONSOLE, debug.traceback())
    tprint(what)
    tprint(schema)
    
    return ("0")
end

-- ##############################################

local function update_rrd(schema, rrdfile, timestamp, data)
    local params = {number_to_rrd_string(timestamp, schema)}

    -- io.write("update_rrd(".. rrdfile ..")\n")

    if isDebugEnabled() then
        traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("Going to update %s [%s]", schema.name, rrdfile))
    end

    -- Verify last update time
    local last_update = ntop.rrd_lastupdate(rrdfile)

    if ((last_update ~= nil) and (timestamp <= last_update)) then
        if isDebugEnabled() then
            traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format(
                "Skip RRD update in the past: timestamp=%u but last_update=%u", timestamp, last_update))
        end

        return false
    end

    for _, metric in ipairs(schema._metrics) do
        params[#params + 1] = number_to_rrd_string(data[metric], schema)
    end

    if isDebugEnabled() then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("ntop.rrd_update(%s, %s) schema=%s", rrdfile, table.concat(params, ", "), schema.name))
    end

    local err = ntop.rrd_update(rrdfile, table.unpack(params))

    if (err ~= nil) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, err)
        return false
    end

    return true
end

-- ##############################################

function driver:append(schema, timestamp, tags, metrics)
    local base, rrd = schema_get_path(schema, tags)
    local rrdfile = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

    if use_rrd_queue then
        if not schema.options.is_critical_ts then
            local res = interface.rrd_enqueue(schema.name, timestamp, tags, metrics)

            if not res then
                ntop.rrd_inc_num_drops()
            end

            return res
        end
    end

    if not ntop.notEmptyFile(rrdfile) then
        ntop.mkdir(base)
        if not create_rrd(schema, rrdfile, timestamp) then
            return false
        end
    end

    return update_rrd(schema, rrdfile, timestamp, metrics)
end

-- ##############################################

local function makeTotalSerie(series, count)
    local total = {}

    for _, serie in pairs(series) do
        for i, val in pairs(serie.data) do
            local val_is_nan = (val ~= val)

            if (total[i] == nil) then
                total[i] = 0
            end

            if (not val_is_nan) then
                total[i] = total[i] + val
            end
        end
    end

    return total
end

-- ##############################################

local function sampleSeries(schema, cur_points, step, max_points, series, consolidation)
    local sampled_dp = math.ceil(cur_points / max_points)
    local count = nil
    local nan = 0 / 0

    for _, data_serie in pairs(series) do
        local serie = data_serie.data
        local num = 0
        local sum = 0
        local all_nan = true
        local end_idx = 1
        local max_val = -1

        for idx, dp in ipairs(serie) do
            if (dp ~= dp) then
                -- Convert NaN to 0 to calculate the sums
                dp = 0
            else
                all_nan = false
            end

            sum = sum + dp
            num = num + 1

            if (dp > max_val) then
                max_val = dp
            end

            if num == sampled_dp then
                -- A data group is ready
                if all_nan then
                    -- If all the points into the datagroup are NaN, calculate them
                    -- as NaN
                    sum = nan
                end

                if (consolidation == "MAX") then
                    serie[end_idx] = max_val
                else
                    serie[end_idx] = sum / num
                end

                end_idx = end_idx + 1

                num = 0
                sum = 0
                all_nan = true
                max_val = 0
            end
        end

        -- Last group
        if num > 0 then
            if all_nan then
                sum = nan
            end

            serie[end_idx] = sum / num
            end_idx = end_idx + 1
        end

        count = end_idx - 1

        -- remove the exceeding points
        for i = end_idx, #serie do
            serie[i] = nil
        end
    end

    -- new step, new count, new data
    return step * sampled_dp, count
end

-- ##############################################

-- Make sure we do not fetch data from RRDs that have been update too much long ago
-- as this creates issues with the consolidation functions when we want to compare
-- results coming from different RRDs.
-- This is also needed to make sure that multiple data series on graphs have the
-- same number of points, otherwise d3js will generate errors.
local function touchRRD(rrdname)
    local now = os.time()
    local last, ds_count = ntop.rrd_lastupdate(rrdname)

    if ((last ~= nil) and ((now - last) > 3600)) then
        local tdiff = now - 1800 -- This avoids to set the update continuously

        if isDebugEnabled() then
            traceError(TRACE_NORMAL, TRACE_CONSOLE,
                string.format("touchRRD(%s, %u), last_update was %u", rrdname, tdiff, last))
            tprint(debug.traceback())
        end

        if (ds_count == 1) then
            ntop.rrd_update(rrdname, tdiff .. "", "0")
        elseif (ds_count == 2) then
            ntop.rrd_update(rrdname, tdiff .. "", "0", "0")
        elseif (ds_count == 3) then
            ntop.rrd_update(rrdname, tdiff .. "", "0", "0", "0")
        elseif (ds_count == 4) then
            ntop.rrd_update(rrdname, tdiff .. "", "0", "0", "0", "0")
        end
    end
end

-- ##############################################

function driver:timeseries_query(options)
    local base, rrd = schema_get_path(options.schema_info, options.tags)
    local rrdfile = options.rrdfile or os_utils.fixPath(base .. "/" .. rrd .. ".rrd")
    local res = nil

    if not ntop.notEmptyFile(rrdfile) then
        return res
    end

    touchRRD(rrdfile)

    -- Get last update
    local last_update = ntop.rrd_lastupdate(rrdfile)

    -- Avoid reporting the last point when the timeseries write has not completed
    -- yet. Use 2*step as a bound.
    if ((options.epoch_end > last_update) and
        ((options.epoch_end - last_update) <= 2 * options.schema_info.options.step)) then
        options.epoch_end = last_update
    end

    local epoch_end = options.epoch_end - options.schema_info.options.step
    local epoch_begin = options.epoch_begin - options.schema_info.options.step
    -- Query rrd to get the data
    -- tprint("rrdtool fetch ".. rrdfile.. " " .. getConsolidationFunction(schema) .. " -s ".. tstart .. " -e " .. tend)
    local consolidation = getConsolidationFunction(options.schema_info)
    local fstart, fstep, fdata, fend, fcount, names = ntop.rrd_fetch_columns(rrdfile, consolidation, epoch_begin,
        epoch_end)

    if fdata == nil then
        return res
    end

    local count = 0
    local series = {}
    local sampled_fstep = fstep
    local serie_idx = 0

    for name, _ in pairs(fdata) do
        serie_idx = serie_idx + 1 -- the first id is 1
        local name = options.schema_info._metrics[serie_idx]

        -- Process the series requested, adding statistics if requested (min, max, tot, ...)
        -- and normalize the data if needed
        local max_val = ts_common.getMaxPointValue(options.schema_info, name, options.tags)

        local fdata_name = names[serie_idx]
        local serie = fdata[fdata_name]
        local modified_serie = {}
        local num_not_nan_pts = 0
        count = 0

        for i, v in pairs(serie) do
            -- Keep track of NaN points
            if v == v then
                num_not_nan_pts = num_not_nan_pts + 1
            end
        end

        -- Normalize the value
        for i, v in pairs(serie) do
            -- Not enough point to represent the data, empty the serie
            if num_not_nan_pts >= options.min_num_points then
                modified_serie[i] = ts_common.normalizeVal(v, max_val, options)
                count = count + 1
            else
                modified_serie[i] = options.fill_value
            end
        end

        series[#series + 1] = {
            data = modified_serie,
            id = name
        }
    end

    if count > options.max_num_points then
        sampled_fstep, count = sampleSeries(options.schema_info, count, fstep, options.max_num_points, series,
            consolidation)
    end

    -- Need to re-iterate all the series, otherwise the stats cannot be
    -- calculated on the sampled serie
    for i, data_serie in pairs(series) do
        -- Add statistics if requested, by default yes
        if options.calculate_stats then
            -- tprint("Schema :" .. series[i].id)
            local s = ts_common.calculateStatistics(series[i].data, sampled_fstep,
                options.schema_info.options.keep_total, options.schema_info.options.metrics_type)
            local min_max = ts_common.calculateMinMax(data_serie.data)
            local statistics = table.merge(s, min_max)
            series[i].statistics = statistics
        end
    end

    res = {
        metadata = {
            epoch_begin = fstart,
            epoch_end = fend,
            epoch_step = sampled_fstep,
            num_point = count or 0,
            schema = options.schema,
            query = options.tags
        },
        series = series
    }

    return res
end

-- ##############################################

function driver:query(schema, tstart, tend, tags, options)
    local base, rrd = schema_get_path(schema, tags)
    local rrdfile = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

    if not ntop.notEmptyFile(rrdfile) then
        return nil
    end

    touchRRD(rrdfile)

    local last_update = ntop.rrd_lastupdate(rrdfile)

    if isDebugEnabled() then
        traceError(TRACE_NORMAL, TRACE_CONSOLE,
            string.format("RRD_FETCH schema=%s %s -> (%s): last_update=%u", schema.name, table.tconcat(tags, "=", ","),
                rrdfile, last_update))
    end

    -- Avoid reporting the last point when the timeseries write has not completed
    -- yet. Use 2*step as a bound.
    if ((tend > last_update) and ((tend - last_update) <= 2 * schema.options.step)) then
        tend = last_update
    end

    -- tprint("rrdtool fetch ".. rrdfile.. " " .. getConsolidationFunction(schema) .. " -s ".. tstart .. " -e " .. tend)
    local fstart, fstep, fdata, fend, fcount, names = ntop.rrd_fetch_columns(rrdfile, getConsolidationFunction(schema),
        tstart, tend)

    if fdata == nil then
        return nil
    end

    local count = 0
    local series = {}

    local serie_idx = 0

    for name, _ in pairs(fdata) do
        serie_idx = serie_idx + 1 -- the first id is 1
        local name = schema._metrics[serie_idx]
        local fdata_name = names[serie_idx]
        serie = fdata[fdata_name]

        local max_val = ts_common.getMaxPointValue(schema, name, tags)
        count = 0

        -- unify the format
        for i, v in pairs(serie) do
            local value = ts_common.normalizeVal(v, max_val, options)
            local val_is_nan = (v ~= v)

            if options.keep_nan == true and val_is_nan then
                value = v
            end

            serie[i] = value
            count = count + 1
        end

        -- Remove the last value: RRD seems to give an additional point
        serie[#serie] = nil
        count = count - 1

        series[serie_idx] = {
            label = name,
            data = serie
        }
    end

    -- table.clone needed as series can be modified below (sampleSeries works on it in-place)
    local unsampled_series = table.clone(series)
    local unsampled_count = count
    local unsampled_fstep = fstep

    if count > options.max_num_points then
        sampled_fstep, count = sampleSeries(schema, count, fstep, options.max_num_points, series)
    else
        sampled_fstep = fstep
    end

    -- local returned_tend = fstart + fstep * (count-1)
    -- tprint(returned_tend .. " " .. fstart)

    local total_series = nil
    local stats = nil

    -- tprint("Step: "..fstep.." / unsampled_fstep: "..unsampled_fstep)
    -- tprint(unsampled_series)

    if options.calculate_stats then
        total_series = makeTotalSerie(series, count)
        -- statistics used in report page
        local total_series = makeTotalSerie(series, count)
        stats = ts_common.calculateStatistics(total_series, sampled_fstep, tend - tstart, schema.options.metrics_type)

        stats = stats or {}
        stats.by_serie = {}

        -- Also calculate per-series statistics
        for k, v in pairs(series) do
            local s = ts_common.calculateStatistics(v.data, sampled_fstep, tend - tstart, schema.options.metrics_type)
            local min_max = ts_common.calculateMinMax(v.data)

            -- Adding per timeseries min-max stats
            stats.by_serie[k] = table.merge(s, min_max)
        end
    end

    if options.initial_point then
        local serie_idx = 1
        local _, _, initial_pt, _, _, names = ntop.rrd_fetch_columns(rrdfile, getConsolidationFunction(schema),
            tstart - schema.options.step, tstart - schema.options.step)
        initial_pt = initial_pt or {}

        for name_key, values in pairs(initial_pt) do
            local name = schema._metrics[serie_idx]
            local max_val = ts_common.getMaxPointValue(schema, name, tags)
            local ptval = ts_common.normalizeVal(values[1], max_val, options)

            table.insert(series[serie_idx].data, 1, ptval)
            serie_idx = serie_idx + 1
        end

        count = count + 1

        if total_series then
            -- recalculate with additional point
            total_series = makeTotalSerie(series, count)
        end
    end

    -- tprint(rrdfile)
    -- tprint(schema)
    -- tprint(schema.options.metrics_type)

    -- tprint("fstep: "..sampled_fstep.." / ".."count: "..count .. " / tot: ".. (sampled_fstep*count))

    if options.calculate_stats then
        stats = table.merge(stats, ts_common.calculateMinMax(total_series))
    end

    return {
        start = fstart,
        step = sampled_fstep,
        count = count,
        series = series,
        statistics = stats,
        additional_series = {
            total = total_series
        }
    }
end

-- ##############################################

-- *Limitation*
-- tags_filter is expected to contain all the tags of the schema except the last
-- one. For such tag, a list of available values will be returned.
function driver:listSeries(schema, tags_filter, wildcard_tags, start_time, not_print_error)
    if #wildcard_tags > 1 then
        if not not_print_error then
            tprint(debug.traceback())
            tprint({
                schema_name = schema.name,
                wildcards = wildcard_tags
            })
            traceError(TRACE_ERROR, TRACE_CONSOLE, "RRD driver does not support listSeries on multiple tags")
        end

        return nil
    end

    local wildcard_tag = wildcard_tags[1]

    if not wildcard_tag then
        local full_path = driver.schema_get_full_path(schema, tags_filter)
        local last_update = ntop.rrd_lastupdate(full_path)

        if last_update ~= nil and last_update >= start_time then
            return {tags_filter}
        else
            return nil
        end
    end

    if wildcard_tag ~= schema._tags[#schema._tags] then
        traceError(TRACE_ERROR, TRACE_CONSOLE,
            "RRD driver only support listSeries with wildcard in the last tag, got wildcard on '" .. wildcard_tag .. "'")
        return nil
    end

    local base, rrd = schema_get_path(schema, table.merge(tags_filter, {
        [wildcard_tag] = ""
    }))
    local files = ntop.readdir(base)
    local res = {}

    -- tprint(base)
    -- tprint(files)

    for f in pairs(files or {}) do
        local v = string.split(f, "%.rrd")
        local fpath = base .. "/" .. f
        if ((v ~= nil) and (#v == 1)) then
            local last_update = ntop.rrd_lastupdate(fpath)
            if last_update ~= nil and last_update >= start_time then
                local value = v[1]
                local toadd = false

                if wildcard_tag == "if_index" then
                    -- NOTE: needed to add this crazy exception. Don't now what it is
                    -- but it's needed, otherwise this function is tricked into thinking
                    -- other timeseries (such as snmp_dev:cpu_states) are if_index
                    --
                    -- This is what we get:
                    -- 1.device string 192.168.2.1
                    -- 1.ifid string -1
                    -- 1.if_index string 5
                    -- 2 table
                    -- 2.device string 192.168.2.1
                    -- 2.ifid string -1
                    -- 2.if_index string 2
                    -- 3 table
                    -- 3.device string 192.168.2.1
                    -- 3.ifid string -1
                    -- 3.if_index string cpu_states <<<<<<<<<<<<<<<<< don't know why this happens to be here
                    -- 4 table
                    --
                    if tonumber(value) then
                        toadd = true
                    end
                elseif wildcard_tag == "dscp_class" then
                    toadd = true
                elseif wildcard_tag == "l4proto" then
                    if L4_PROTO_KEYS[value] ~= nil then
                        toadd = true
                    end
                elseif ((wildcard_tag ~= "protocol") or
                    ((L4_PROTO_KEYS[value] == nil) and interface.getnDPIProtoId(value) ~= 0)) and
                    ((wildcard_tag ~= "category") or (interface.getnDPICategoryId(value) ~= -1)) then
                    toadd = true
                end

                if toadd then
                    res[#res + 1] = table.merge(tags_filter, {
                        [wildcard_tag] = value
                    })
                end
            end
        elseif ntop.isdir(fpath) then
            fpath = fpath .. "/" .. rrd .. ".rrd"

            local last_update = ntop.rrd_lastupdate(fpath)

            if last_update ~= nil and last_update >= start_time then
                res[#res + 1] = table.merge(tags_filter, {
                    [wildcard_tag] = f
                })
            end
        end
    end

    return res
end

-- ##############################################

function driver:timeseries_top(options, top_tags)
    if #top_tags > 1 then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "RRD driver does not support topk on multiple tags")
        return nil
    end

    local top_tag = top_tags[1]

    if top_tag ~= options.schema_info._tags[#options.schema_info._tags] then
        traceError(TRACE_ERROR, TRACE_CONSOLE,
            "RRD driver only support topk with topk tag in the last tag, got topk on '" .. (top_tag or "") .. "'")
        return nil
    end

    local series = driver:listSeries(options.schema_info, options.tags, top_tags, options.epoch_begin)
    if not series then
        return nil
    end

    local available_items = {}
    local available_tags = {}
    local available_series = {}
    local total_valid = true
    local step = 0
    local query_start = options.epoch_begin
    local cf = getConsolidationFunction(options.schema_info)

    -- Quering all the different schema and unify all the data
    for _, serie_tags in pairs(series) do
        local rrdfile = driver.schema_get_full_path(options.schema_info, serie_tags)
        options.rrdfile = rrdfile
        local options_merged = options
        options_merged.tags = serie_tags
        local stats = driver:timeseries_query(options_merged)
        local partials = {}
        local serie_idx = 0

        if stats then
            local sum = 0
            step = stats.metadata.epoch_step
            local aggregated_serie = {}
            local statistics = {}
            -- For each serie, get the sum and other stats
            for _, serie in pairs(stats.series or {}) do
                serie_idx = serie_idx + 1 -- the first id is 1
                local name = options.schema_info._metrics[serie_idx]

                if table.len(statistics) == 0 then
                    statistics = serie.statistics
                else
                    for stat_name, value in pairs(serie.statistics) do
                        statistics[stat_name] = statistics[stat_name] + value
                    end
                end
                partials[name] = 0

                for i, serie_point in pairs(serie.data) do
                    local val_is_nan = (serie_point ~= serie_point)

                    if not val_is_nan then
                        sum = sum + tonumber(serie_point)
                    end

                    if not aggregated_serie[i] then
                        aggregated_serie[i] = 0
                    end

                    aggregated_serie[i] = aggregated_serie[i] + serie_point
                    partials[name] = partials[name] + serie_point * step
                end
            end

            available_items[serie_tags[top_tag]] = sum * step
            available_tags[serie_tags[top_tag]] = {serie_tags, partials}
            available_series[serie_tags[top_tag]] = {
                data = aggregated_serie,
                statistics = statistics,
                tags = options_merged.tags
            }
        end
    end

    local top_series = {}
    local count = 0
    local id = "bytes"

    if ends(options.schema, "packets") then
        id = "packets"
    elseif ends(options.schema, "hits") then
        id = "hits"
    end

    for top_item, value in pairsByValues(available_items, rev) do
        if value > 0 then
            package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
            local snmp_utils = require "snmp_utils"
            local snmp_cached_dev = require "snmp_cached_dev"
            local cached_device = snmp_cached_dev:create(options.tags.device)
            local ifindex = available_tags[top_item][1].if_index or available_tags[top_item][1].port
            local ext_label = nil
            if cached_device then
                ext_label = snmp_utils.get_snmp_interface_label(cached_device["interfaces"][ifindex])
                if isEmptyString(ext_label) then
                    ext_label = ifindex
                end
            end

            count = table.len(available_series[top_item].data)
            top_series[#top_series + 1] = {
                data = available_series[top_item].data,
                id = id,
                statistics = available_series[top_item].statistics,
                tags = available_series[top_item].tags,
                name = top_item,
                ext_label = ext_label
            }
        end

        if #top_series >= options.top then
            break
        end
    end

    local stats = nil

    return {
        metadata = {
            epoch_begin = options.epoch_begin,
            epoch_end = options.epoch_end,
            epoch_step = step,
            num_point = count,
            schema = options.schema,
            query = options.tags
        },
        series = top_series
    }
end

-- ##############################################

function driver:topk(schema, tags, tstart, tend, options, top_tags)
    if #top_tags > 1 then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "RRD driver does not support topk on multiple tags")
        return nil
    end

    local top_tag = top_tags[1]

    if top_tag ~= schema._tags[#schema._tags] then
        traceError(TRACE_ERROR, TRACE_CONSOLE,
            "RRD driver only support topk with topk tag in the last tag, got topk on '" .. (top_tag or "") .. "'")
        return nil
    end

    local series = driver:listSeries(schema, tags, top_tags, tstart, tend)
    if not series then
        return nil
    end

    local items = {}
    local tag_2_series = {}
    local total_series = {}
    local total_valid = true
    local step = 0
    local query_start = tstart
    local cf = getConsolidationFunction(schema)

    if options.initial_point then
        query_start = tstart - schema.options.step
    end

    for _, serie_tags in pairs(series) do
        local rrdfile = driver.schema_get_full_path(schema, serie_tags)

        if isDebugEnabled() then
            traceError(TRACE_NORMAL, TRACE_CONSOLE,
                string.format("RRD_FETCH[topk] schema=%s %s[%s] -> (%s): last_update=%u", schema.name,
                    table.tconcat(tags, "=", ","), table.concat(top_tags, ","), rrdfile, ntop.rrd_lastupdate(rrdfile)))
        end

        touchRRD(rrdfile)

        local fstart, fstep, fdata, fend, fcount, names = ntop.rrd_fetch_columns(rrdfile, cf, query_start, tend)
        local sum = 0

        if fdata == nil then
            goto continue
        end

        step = fstep

        local partials = {}

        local serie_idx = 0
        for _, _ in pairs(fdata) do
            serie_idx = serie_idx + 1 -- the first id is 1
            local name = schema._metrics[serie_idx]
            local fdata_name = names[serie_idx]
            serie = fdata[fdata_name]

            local max_val = ts_common.getMaxPointValue(schema, name, serie_tags)
            partials[name] = 0

            -- Remove the last value: RRD seems to give an additional point
            serie[#serie] = nil

            if (#total_series ~= 0) and #total_series ~= #serie then
                -- NOTE: even if touchRRD is used, series can still have a different number
                -- of points when the tend parameter does not correspond to the current time
                -- e.g. when comparing with the past or manually zooming.
                -- In this case, total serie il discarded as it's incorrect
                total_valid = false
            end

            for i = #total_series + 1, #serie do
                -- init
                total_series[i] = 0
            end

            for i, v in pairs(serie) do
                local v = ts_common.normalizeVal(v, max_val, options)

                if type(v) == "number" then
                    sum = sum + v
                    partials[name] = partials[name] + v * step
                    total_series[i] = total_series[i] + v
                end
            end
        end

        items[serie_tags[top_tag]] = sum * step
        tag_2_series[serie_tags[top_tag]] = {serie_tags, partials}

        ::continue::
    end

    local topk = {}

    for top_item, value in pairsByValues(items, rev) do
        if value > 0 then
            topk[#topk + 1] = {
                tags = tag_2_series[top_item][1],
                value = value,
                partials = tag_2_series[top_item][2]
            }
        end

        if #topk >= options.top then
            break
        end
    end

    local stats = nil

    -- table.clone needed as augumented_total can be modified below (sampleSeries works on it in-place)
    local augumented_total = table.clone(total_series)

    if options.initial_point and total_series then
        -- remove initial point to avoid stats calculation on it
        table.remove(total_series, 1)
    end

    local fstep, count = sampleSeries(schema, #augumented_total, step, options.max_num_points, {{
        data = augumented_total
    }})

    if options.calculate_stats then
        stats = ts_common.calculateStatistics(total_series, step, tend - tstart, schema.options.metrics_type)
        stats = table.merge(stats, ts_common.calculateMinMax(augumented_total))
    end

    if not total_valid then
        total_series = nil
        augumented_total = nil
    end

    return {
        topk = topk,
        additional_series = {
            total = augumented_total
        },
        statistics = stats
    }

end

-- ##############################################

function driver:queryTotal(schema, tstart, tend, tags, options)
    local rrdfile = driver.schema_get_full_path(schema, tags)
    if not rrdfile or not ntop.notEmptyFile(rrdfile) then
        return nil
    end

    touchRRD(rrdfile)

    local fstart, fstep, fdata, fend, fcount, names = ntop.rrd_fetch_columns(rrdfile, getConsolidationFunction(schema),
        tstart, tend)
    local totals = {}

    local serie_idx = 0
    for _, _ in pairs(fdata or {}) do
        serie_idx = serie_idx + 1 -- the first id is 1
        local name = schema._metrics[serie_idx]
        local fdata_name = names[serie_idx]
        local serie = fdata[fdata_name]

        local max_val = ts_common.getMaxPointValue(schema, name, tags)
        local sum = 0

        -- Remove the last value: RRD seems to give an additional point
        serie[#serie] = nil

        for i, v in pairs(serie) do
            local v = ts_common.normalizeVal(v, max_val, options)

            -- v is not null
            if v == v then
                sum = sum + v * fstep
            end
        end

        totals[name] = sum
    end

    return totals
end

-- ##############################################

function driver:queryLastValues(options)
    local rrdfile = driver.schema_get_full_path(options.schema_info, options.tags)
    if not rrdfile or not ntop.notEmptyFile(rrdfile) then
        return nil
    end

    touchRRD(rrdfile)

    local fstart, fstep, fdata, fend, fcount, names = ntop.rrd_fetch_columns(rrdfile, getConsolidationFunction(
        options.schema_info), options.epoch_begin, options.epoch_end)
    local last_values = {}

    local serie_idx = 0
    for _, _ in pairs(fdata or {}) do
        serie_idx = serie_idx + 1 -- the first id is 1
        local name = options.schema_info._metrics[serie_idx]
        local fdata_name = names[serie_idx]
        local serie = fdata[fdata_name]

        local max_val = ts_common.getMaxPointValue(options.schema_info, name, options.tags)

        -- Remove the last value: RRD seems to give an additional point
        serie[#serie] = nil

        local values = {}
        -- Start from the last series item - 1 because RRD seems to give an additional point
        for i = (#serie - 1), 1, -1 do
            if (#values == options.num_points) then
                break
            end
            -- nan check
            if serie[i] == serie[i] then
                values[#values + 1] = ts_common.normalizeVal(serie[i], max_val, options)
            end
        end
        last_values[name] = values
    end
    return last_values
end

-- ##############################################

local function deleteAllData(ifid)
    local paths = getRRDPaths()

    for _, path in pairs(paths) do
        local ifpath = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/" .. path .. "/")
        local path_to_del = os_utils.fixPath(ifpath)

        if ntop.exists(path_to_del) and not ntop.rmdir(path_to_del) then
            return false
        end
    end

    return true
end

-- ##############################################

function driver:delete(schema_prefix, tags)
    if schema_prefix == "" then
        -- Delete all data
        return deleteAllData(tags.ifid)
    end

    -- In RRD we must determine the root path of a given entity (e.g. of an
    -- host if schema_prefix is "host", of a network if schema_prefix is "subnet"
    -- and so on). In order to do so, we list all the schemas starting with the
    -- given prefix, then determine the shortest path to be deleted.
    --
    -- E.g. for ts_utils.delete("mac", {ifid=1, mac="11:22:33:44:55:66"})
    -- we find the following paths:
    --  - /var/lib/ntopng/-1/rrd/macs/11_22_33/44/55/66 (schema "mac:traffic")
    --  - /var/lib/ntopng/-1/rrd/macs/11_22_33/44/55/66/ndpi_categories (schema "mac:ndpi_categories")
    -- We delete the shortest ("/var/lib/ntopng/-1/rrd/macs/11_22_33/44/55/66") as it includes the other.
    --
    -- NOTE: this logic assumes that schemas are well defined, which
    -- means that:
    --  - The first tag is the "ifid" tag
    --  - Tags are defined in order of cardinality, e.g. the "host" tag is
    --    defined before the "protocol" tag
    local ts_utils = require "ts_utils" -- required to get the schemas
    local num_valorized_tags = table.len(tags)
    local s_prefix = schema_prefix .. ""

    if (num_valorized_tags < 1) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "At least 1 tags must be specified for the delete operation")
        return false
    end

    local found = nil

    -- Iterate the entity schemas and find the shortest RRD directory path
    for k, s in pairs(ts_utils.getLoadedSchemas()) do
        if starts(k, s_prefix) then
            local unreleted = false

            -- Ensure that all the tags are valorized in order to avoid
            -- deleting unrelated data
            for k in pairs(tags) do
                if (s.tags[k] == nil) then
                    -- Missing tag, this schema is possibly unrelated
                    unreleted = true
                    break
                end
            end

            if (not unreleted) then
                local check_tags = {}

                -- Fill the missing tags with empty strings to account them as
                -- possible shortest paths
                for k in pairs(s.tags) do
                    check_tags[k] = tags[k] or ""
                end

                local path = schema_get_path(s, check_tags)

                -- Choose the shortest string to pick the path that includes the others
                if path and ((found == nil) or (string.len(path) < string.len(found))) then
                    found = path
                end
            end
        end
    end

    if (not found) then
        return false
    end

    local path_to_del = os_utils.fixPath(found)

    if ntop.exists(path_to_del) and not ntop.rmdir(path_to_del) then
        return false
    end

    if isDebugEnabled() then
        traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("DELETE schema=%s, %s => %s", schema_prefix,
            table.tconcat(tags, "=", ","), path_to_del))
    end

    return true
end

-- ##############################################

function driver:deleteOldData(ifid)
    local data_retention_utils = require "data_retention_utils"
    local paths = getRRDPaths()
    local dirs = ntop.getDirs()
    local retention_days = data_retention_utils.getTSAndStatsDataRetentionDays()

    for _, path in pairs(paths) do
        local ifpath = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/" .. path .. "/")
        local deadline = retention_days * 86400

        if isDebugEnabled() then
            traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("ntop.deleteOldRRDs(%s, %u)", ifpath, deadline))
        end

        ntop.deleteOldRRDs(ifpath, deadline)
    end

    return true
end

-- ##############################################

function driver:setup(ts_utils)
    return true
end

-- ##############################################

-- Parses a line in line protocol format (https://docs.influxdata.com/influxdb/v1.7/write_protocols/line_protocol_tutorial/)
-- into tags and metrics
local function line_protocol_to_tags_and_metrics(protocol_line)
    -- An example of line protocol is the following
    --
    -- weather,location=us-midwest temperature=82 1465839830100400200
    --    |    -------------------- --------------  |
    --    |             |             |             |
    --    |             |             |             |
    --    +-----------+--------+-+---------+-+---------+
    --    |measurement|,tag_set| |field_set| |timestamp|
    --    +-----------+--------+-+---------+-+---------+
    --
    -- NOTE: no need to worry about possible spaces in the tag names. As we are using a regexp to parse
    -- the line, and regexps are greedy, spaces in the tags won't be of any issue. Examples that are correctly parsed are:
    --
    -- local test_line2 = "iface:traffic_rxtx,ifid=0 bytes_sent=849500,bytes_rcvd=5134958 1583007829\n"
    -- local test_line = "iface:traffic_rxtx,ifid=0,ndpi_category=My Category,ndpi_proto=Apple iTunes,host=1.2.3.4 bytes_sent=849500,bytes_rcvd=5134958 1583007829\n"
    --
    local measurement_and_tag_set, field_set, timestamp = protocol_line:match("(.+)%s(.+)%s(.+)\n")

    local measurement
    local tags = {}
    local metrics = {}

    -- Parse measurement and tags
    local items = measurement_and_tag_set:split(",")
    if not items then
        -- no tag set, just the measurement
        measurement = measurement_and_tag_set
    else
        -- measurement is at position 1, tags at positions 2+
        measurement = items[1]
        for i = 2, #items do
            local tag_items = items[i]:split("=")
            if tag_items and #tag_items == 2 then
                tags[tag_items[1]] = tonumber(tag_items[2]) or tag_items[2]
            end
        end
    end

    -- Parse metrics
    local items = field_set:split(",")
    if not items then
        -- Just one metric
        items = {field_set}
    end

    for i = 1, #items do
        local field_items = items[i]:split("=")

        if field_items and #field_items == 2 then
            metrics[field_items[1]] = tonumber(field_items[2]) or field_items[2]
        end
    end

    local res = {
        schema_name = measurement,
        tags = tags,
        metrics = metrics,
        timestamp = tonumber(timestamp)
    }

    return res
end

-- ##############################################

function driver:export()
    if (not (use_rrd_queue)) then
        return -- Nothing to do
    end

    local ts_utils = require "ts_utils" -- required to get the schema from the schema name

    local available_interfaces = interface.getIfNames() or {}
    -- Add the system interface to the available interfaces
    available_interfaces[getSystemInterfaceId()] = getSystemInterfaceName()
    local rrd_queue_max_dequeues_per_interface = 8192

    for cur_ifid, iface in pairs(available_interfaces) do
        for cur_dequeue = 1, rrd_queue_max_dequeues_per_interface do
            local ts_point = interface.rrd_dequeue(tonumber(cur_ifid))

            if not ts_point then
                break
            end

            local parsed_ts_point = line_protocol_to_tags_and_metrics(ts_point)

            -- No need to do coherence checks on the schema. This queue is 'private' and should
            -- only be written with valid data already checked.
            local schema = ts_utils.getSchema(parsed_ts_point["schema_name"])
            local timestamp = parsed_ts_point["timestamp"]
            local tags = parsed_ts_point["tags"]
            local metrics = parsed_ts_point["metrics"]
            local base, rrd = schema_get_path(schema, tags)

            if rrd then
                local rrdfile = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

                if not ntop.notEmptyFile(rrdfile) then
                    ntop.mkdir(base)
                    if not create_rrd(schema, rrdfile, timestamp) then
                        return false
                    end
                end

                update_rrd(schema, rrdfile, timestamp, metrics)
            end
        end
    end
end

-- ##############################################

return driver
