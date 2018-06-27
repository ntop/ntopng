--
-- (C) 2018 - ntop.org
--

--[[
Data model:

  - schema: a set of <schema_name, tags, metrics, options>
  - schema_name: a unique schema identifier
  - tags: an ordered list of <tag_name, tag_value>. A tag is an instance identifier.
  - metrics: an ordered list of metrics.
    - metric: a single metric (e.g. byte sent) for the instance within the schema.
  - options: variable options, divided between driver dependent/independent
    E.g. {step=60, driver={rrd={ .. RRD specific options ..}}}
]]

local ts_utils = {}

-- Import other modules
ts_utils.metrics = require "ts_types"
ts_utils.schema = require "ts_schema"
require("ntop_utils")

package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/schemas/?.lua;" .. package.path

-----------------------------------------------------------------------

-- All the drivers

--TODO
local dirs = ntop.getDirs()
local rrd_driver = require("rrd"):new({base_path = (dirs.workingdir .. "/rrd_new")})
local influxdb_driver = nil
local loaded_schemas = {}

if not isEmptyString(ntop.getCache("ntopng.prefs.ts_post_data_url")) then
  influxdb_driver = require("influxdb"):new()
end

function ts_utils.newSchema(name, options)
  local schema = ts_utils.schema:new(name, options)

  if loaded_schemas[name] ~= nil then
    traceError(TRACE_WARNING, TRACE_CONSOLE, "Schema already defined: " .. name)
    return loaded_schemas[name]
  end

  loaded_schemas[name] = schema

  return schema
end

function ts_utils.getSchema(name)
  return loaded_schemas[name]
end

function ts_utils.getLoadedSchemas()
  return loaded_schemas
end

function ts_utils.listDrivers()
  -- TODO
  return {rrd_driver, influxdb_driver}
end

-- Only active drivers
function ts_utils.listActiveDrivers()
  -- TODO
  return {rrd_driver, influxdb_driver}
end

function ts_utils.enableDriver(driver)
  --TODO
end

function ts_utils.disableDriver(driver)
  --TODO
end

-- Get the driver to use to query data
function ts_utils.getQueryDriver()
  local drivers = ts_utils.listActiveDrivers()

  -- TODO: for now prefer the influx driver if present
  local driver = drivers[2] or drivers[1]

  return driver
end

-----------------------------------------------------------------------

function ts_utils.append(schema_name, tags_and_metrics, timestamp, verbose)
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

  if verbose then
    traceError(TRACE_NORMAL, TRACE_CONSOLE, "TS.UPDATE [".. schema.name .."] " .. table.tconcat(tags_and_metrics, "=", ","))
  end

  for _, driver in pairs(ts_utils.listActiveDrivers()) do
    rv = driver:append(schema, timestamp, tags, data) and rv
  end

  return rv
end

-- NOTE: data aggregation/sampling should be avoided when possible by appropriately
-- tuning the retention policies to provide a reasonable amount of data.
local function aggregate_dp(schema, select_data, max_points)
  local cur_points = select_data.count
  local step = select_data.step
  local sampled_dp = math.ceil(select_data.count / max_points)

  local count = nil

  for _, data_serie in pairs(select_data.series) do
    local serie = data_serie.data
    local num = 0
    local sum = 0
    local end_idx = 1

    for _, dp in ipairs(serie) do
      sum = sum + dp
      num = num + 1

      if num == sampled_dp then
        -- A data group is ready
        serie[end_idx] = sum
        end_idx = end_idx + 1

        num = 0
        sum = 0
      end
    end

    -- Last group
    if num > 0 then
      serie[end_idx] = sum
      end_idx = end_idx + 1
    end

    count = end_idx-1

    -- remove the exceeding points
    for i = end_idx, #serie do
      serie[i] = nil
    end
  end

  select_data.step = select_data.step * sampled_dp
  select_data.count = count
  return select_data
end

-----------------------------------------------------------------------

function ts_utils.query(schema_name, tags, tstart, tend, options)
  local query_options = table.merge({
    fill_value = 0,         -- e.g. 0/0 for nan
    min_value = 0,          -- minimum value of a data point
    max_value = math.huge,  -- maximum value for a data point
  }, options or {})

  local schema = ts_utils.getSchema(schema_name)

  if not schema then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
    return false
  end

  if not schema:verifyTags(tags) then
    return nil
  end

  local drivers = ts_utils.listActiveDrivers()

  -- TODO: for now prefer the influx driver if present
  local driver = ts_utils.getQueryDriver()

  if not driver then
    return nil
  end

  -- Prevent queries returning too much points
  local MAX_NUM_POINTS = 480
  local rv = driver:query(schema, tstart, tend, tags, query_options)

  if rv and (rv.count > MAX_NUM_POINTS) then
    -- try to aggregate
    local compact = aggregate_dp(schema, rv, MAX_NUM_POINTS)

    if (not compact) or (compact.count > MAX_NUM_POINTS) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "TS.QUERY: Max number of points exceeded: " .. rv.count .. " > " .. MAX_NUM_POINTS)
      return nil
    end

    -- successfully compacted
    rv = compact
  end

  return rv
end

-----------------------------------------------------------------------

-- List all the data series matching the given filter.
-- Only data series updated after start_time will be returned.
-- Returns a list of expanded tags based on the matches.
function ts_utils.listSeries(schema_name, tags_filter, start_time)
  local schema = ts_utils.getSchema(schema_name)

  if not schema then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Schema not found: " .. schema_name)
    return false
  end

  local driver = ts_utils.getQueryDriver()

  if not driver then
    return nil
  end

  local wildcard_tags = {}

  for tag in pairs(schema.tags) do
    if not tags_filter[tag] then
      wildcard_tags[#wildcard_tags + 1] = tag
    end
  end

  return driver:listSeries(schema, tags_filter, wildcard_tags, start_time)
end

-----------------------------------------------------------------------

function ts_utils.flush()
  local rv = true

  for _, driver in pairs(ts_utils.listActiveDrivers()) do
    rv = driver:flush() and rv
  end

  return rv
end

-----------------------------------------------------------------------

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

-----------------------------------------------------------------------

return ts_utils
