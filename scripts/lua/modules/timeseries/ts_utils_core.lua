--
-- (C) 2018 - ntop.org
--

local ts_utils = {}

local ts_common = require "ts_common"

ts_utils.metrics = ts_common.metrics
ts_utils.schema = require "ts_schema"

require "lua_trace"
require "ntop_utils"

package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/schemas/?.lua;" .. package.path

-- ##############################################

local loaded_schemas = {}

--! @brief Define a new timeseries schema.
--! @param name the schema identifier.
--! @return the newly created schema.
function ts_utils.newSchema(name, options)
  local schema = ts_utils.schema:new(name, options)

  if loaded_schemas[name] ~= nil then
    traceError(TRACE_WARNING, TRACE_CONSOLE, "Schema already defined: " .. name)
    return loaded_schemas[name]
  end

  loaded_schemas[name] = schema

  return schema
end

--! @brief Find schema by name.
--! @param name the schema identifier.
--! @return a schema object on success, nil on error.
function ts_utils.getSchema(name)
  return loaded_schemas[name]
end

function ts_utils.getLoadedSchemas()
  return loaded_schemas
end

--! @brief Return a list of active timeseries drivers.
--! @return list of driver objects.
function ts_utils.listActiveDrivers()
  local driver = ts_utils.getDriverName()
  local active_drivers = {}

  if driver == "rrd" then
    local dirs = ntop.getDirs()
    local rrd_driver = require("rrd"):new({base_path = (dirs.workingdir .. "/rrd_new")})
    active_drivers[#active_drivers + 1] = rrd_driver
  elseif driver == "influxdb" then
    local auth_enabled = (ntop.getPref("ntopng.prefs.influx_auth_enabled") == "1")

    local influxdb_driver = require("influxdb"):new({
      url = ntop.getPref("ntopng.prefs.ts_post_data_url"),
      db = ntop.getPref("ntopng.prefs.influx_dbname"),
      username = ternary(auth_enabled, ntop.getPref("ntopng.prefs.influx_username"), nil),
      password = ternary(auth_enabled, ntop.getPref("ntopng.prefs.influx_password"), nil),
    })
    active_drivers[#active_drivers + 1] = influxdb_driver
  end

  return active_drivers
end

-- Get the driver to use to query data
function ts_utils.getQueryDriver()
  local drivers = ts_utils.listActiveDrivers()

  -- TODO: for now prefer the influx driver if present
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

--! @brief Append a new data point to the specified timeseries.
--! @param schema_name the schema identifier.
--! @param tags_and_metrics a table with tag->value and metric->value mappings.
--! @param timestamp the timestamp associated with the data point.
--! @return true on success, false on error.
function ts_utils.append(schema_name, tags_and_metrics, timestamp)
  timestamp = timestamp or os.time()
  local schema = ts_utils.getSchema(schema_name)

  if not schema then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
    return false
  end

  local tags, data = schema:verifyTagsAndMetrics(tags_and_metrics)

  if not tags then
    return false
  end

  local rv = true

  --traceError(TRACE_NORMAL, TRACE_CONSOLE, "TS.UPDATE [".. schema.name .."] " .. table.tconcat(tags_and_metrics, "=", ","))

  for _, driver in pairs(ts_utils.listActiveDrivers()) do
    rv = driver:append(schema, timestamp, tags, data) and rv
  end

  return rv
end

-- ##############################################

-- Get some default options to use in queries.
local function getQueryOptions(overrides)
  return table.merge({
    max_num_points = 80,    -- maximum number of points per data serie
    fill_value = 0,         -- e.g. 0/0 for nan
    min_value = 0,          -- minimum value of a data point
    max_value = math.huge,  -- maximum value for a data point
    top = 8,                -- topk number of items
    calculate_stats = true, -- calculate stats if possible
    initial_point = false,   -- add an extra initial point, not accounted in statistics but useful for drawing graphs
  }, overrides or {})
end

-- ##############################################

--! @brief Perform a query to extract timeseries data.
--! @param schema_name the schema identifier.
--! @param tags a list of filter tags. All the tags for the given schema must be specified.
--! @param tstart lower time for the query.
--! @param tend upper time for the query.
--! @param options (optional) query options.
--! @return query result on success, nil on error.
function ts_utils.query(schema_name, tags, tstart, tend, options)
  local query_options = getQueryOptions(options)
  local schema = ts_utils.getSchema(schema_name)

  if not schema then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
    return nil
  end

  if not schema:verifyTags(tags) then
    return nil
  end

  local driver = ts_utils.getQueryDriver()

  if not driver then
    return nil
  end

  local rv = driver:query(schema, tstart, tend, tags, query_options)

  if not rv then
    return nil
  end

  -- Add tags information for consistency with queryTopk
  for _, serie in pairs(rv.series) do
    serie.tags = tags
  end

  return rv
end

-- ##############################################

local function getLocalTopTalkers(schema_id, tags, tstart, tend, options)
  package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
  local top_utils = require "top_utils"
  local num_minutes = (tend-tstart)/60
  local top_talkers = top_utils.getAggregatedTop(getInterfaceName(ifId), tend, num_minutes)

  local direction
  local select_col

  if schema_id == "local_senders" then
     direction = "senders"
     select_col = "sent"
  else
     direction = "receivers"
     select_col = "rcvd"
  end

  local tophosts = {}

  for idx1, vlan in pairs(top_talkers.vlan or {}) do
    for idx2, host in pairs(vlan.hosts[1][direction] or {}) do
      if host["local"] == "true" then
        tophosts[idx1.."_"..idx2] = host.value
      end
    end
  end

  local res = {}
  for item in pairsByValues(tophosts, rev) do
    local parts = split(item, "_")
    local idx1 = tonumber(parts[1])
    local idx2 = tonumber(parts[2])
    local host = top_talkers.vlan[idx1].hosts[1][direction][idx2]

    res[#res + 1] = {
      value = host.value,
      tags = {ifid=tags.ifid, host=host.address},
    }

    if #res >= options.top then
      break
    end
  end

  return {
    topk = res,
    schema = ts_utils.getSchema("host:traffic"),
  }
end

-- A bunch of pre-computed top items functions
-- Must return in the same format as driver:topk
local function getPrecomputedTops(schema_id, tags, tstart, tend, options)
  if (schema_id == "local_senders") or (schema_id == "local_receivers") then
    return getLocalTopTalkers(schema_id, tags, tstart, tend, options)
  end

  return nil
end

-- ##############################################

--! @brief Perform a topk query.
--! @param schema_name the schema identifier.
--! @param tags a list of filter tags. All the tags for the given schema must be specified.
--! @param tstart lower time bound for the query.
--! @param tend upper time bound for the query.
--! @param options (optional) query options.
--! @return query result on success, nil on error.
function ts_utils.queryTopk(schema_name, tags, tstart, tend, options)
  local query_options = getQueryOptions(options)
  local top_items = nil
  local schema = nil

  local driver = ts_utils.getQueryDriver()

  if not driver then
    return nil
  end

  local pre_computed = getPrecomputedTops(schema_name, tags, tstart, tend, query_options)

  if pre_computed then
    -- Use precomputed top items
    top_items = pre_computed
    schema = pre_computed.schema
  else
    schema = ts_utils.getSchema(schema_name)

    if not schema then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
      return nil
    end

    local top_tags = {}

    for _, tag in ipairs(schema._tags) do
      if not tags[tag] then
        top_tags[#top_tags + 1] = tag
      end
    end

    if table.empty(top_tags) then
      -- no top tags, just a plain query
      return ts_utils.query(schema_name, tags, tstart, tend, query_options)
    end

    -- Find the top items
    top_items = driver:topk(schema, tags, tstart, tend, query_options, top_tags)
  end

  if not top_items then
    return nil
  end

  top_items.series = {}

  -- Query the top items data
  local options = table.merge(query_options, {calculate_stats = false})
  local count = 0
  local step = nil
  local start = 0

  for _, top in ipairs(top_items.topk) do
    local top_res = driver:query(schema, tstart, tend, top.tags, options)

    if not top_res then
      --traceError(TRACE_WARNING, TRACE_CONSOLE, "Topk series query on '" .. schema.name .. "' with filter '".. table.tconcat(top.tags, "=", ",") .."' returned nil")
      goto continue
    end

    if #top_res.series > 1 then
      -- Unify multiple series into one (e.g. for Top Protocols)
      local aggregated = {}

      for i=1,top_res.count do
        aggregated[i] = 0
      end

      for _, serie in pairs(top_res.series) do
        for i, v in pairs(serie.data) do
          aggregated[i] = aggregated[i] + v
        end
      end

      top_res.series = {{label="bytes", data=aggregated}}
    end

    for _, serie in pairs(top_res.series) do
      count = math.max(#serie.data, count)
    end

    start = top_res.start
    if step then
      step = math.min(step, top_res.step)
    else
      step = top_res.step
    end

    for _, serie in ipairs(top_res.series) do
      serie.tags = top.tags
      top_items.series[#top_items.series + 1] = serie
    end

    ::continue::
  end

  -- Possibly fix series inconsistencies due to RRA steps
  for _, serie in pairs(top_items.series or {}) do
    if count > #serie.data then
      traceError(TRACE_INFO, TRACE_CONSOLE, "Upsampling " .. table.tconcat(serie.tags, "=", ",") .. " from " .. #serie.data .. " to " .. count)
      serie.data = ts_common.upsampleSerie(serie.data, count)
    end
  end
  for key, serie in pairs(top_items.additional_series or {}) do
    if count > #serie then
      traceError(TRACE_INFO, TRACE_CONSOLE, "Upsampling " .. key .. " from " .. #serie .. " to " .. count)
      top_items.additional_series[key] = ts_common.upsampleSerie(serie, count)
    end
  end

  top_items.count = count
  top_items.step = step
  top_items.start = start

  return top_items
end

-- ##############################################

--! @brief List all available timeseries for the specified schema, tags and time.
--! @param schema_name the schema identifier.
--! @param tags_filter a list of filter tags. Tags which are not specified are considered wildcard.
--! @param start_time time filter. Only timeseries updated after start_time will be returned.
--! @return a (possibly empty) list of tags values for the matching timeseries on success, nil on error.
function ts_utils.listSeries(schema_name, tags_filter, start_time)
  local schema = ts_utils.getSchema(schema_name)

  if not schema then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
    return nil
  end

  local driver = ts_utils.getQueryDriver()

  if not driver then
    return nil
  end

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

  return driver:listSeries(schema, filter_tags, wildcard_tags, start_time)
end

-- ##############################################

--! @brief A shortcut for ts_utils.listSeries to verify timeseries existance.
--! @param schema_name the schema identifier.
--! @param tags_filter a list of filter tags. Tags which are not specified are considered wildcard.
--! @return true if the specified series exist, false otherwise.
function ts_utils.exists(schema_name, tags_filter)
  return not table.empty(ts_utils.listSeries(schema_name, tags_filter, 0))
end

-- ##############################################

function ts_utils.delete(schema_name, tags)
  local schema = ts_utils.getSchema(schema_name)

  if not schema then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
    return false
  end

  if not schema:verifyTags(data) then
    return false
  end

  local rv = true

  for _, driver in pairs(ts_utils.listActiveDrivers()) do
    rv = driver:delete(schema, tags) and rv
  end

  return rv
end

-- ##############################################

return ts_utils
