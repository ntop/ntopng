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
ts_utils.metrics = (require "ts_common").metrics
ts_utils.schema = require "ts_schema"

require "lua_trace"
require "ntop_utils"

package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/schemas/?.lua;" .. package.path

-- ##############################################

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

-- ##############################################

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

-- ##############################################

local function getQueryOptions(overrides)
  return table.merge({
    max_num_points = 240,   -- maximum number of points per data serie
    fill_value = 0,         -- e.g. 0/0 for nan
    min_value = 0,          -- minimum value of a data point
    max_value = math.huge,  -- maximum value for a data point
    top = 10,               -- topk number of items
    calculate_stats = true,      -- calculate stats if possible
  }, overrides or {})
end

-- ##############################################

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

function ts_utils.queryTopk(schema_id, tags, tstart, tend, options)
  local query_options = getQueryOptions(options)
  local top_items = nil
  local schema = nil

  local driver = ts_utils.getQueryDriver()

  if not driver then
    return nil
  end

  local pre_computed = getPrecomputedTops(schema_id, tags, tstart, tend, query_options)

  if pre_computed then
    -- Use precomputed top items
    top_items = pre_computed
    schema = pre_computed.schema
  else
    schema = ts_utils.getSchema(schema_id)

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
      return ts_utils.query(schema_id, tags, tstart, tend, query_options)
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

    -- TODO add more checks on consistency?
    top_items.step = top_res.step
    top_items.count = top_res.count
    top_items.start = top_res.start

    for _, serie in ipairs(top_res.series) do
      serie.tags = top.tags
      top_items.series[#top_items.series + 1] = serie
    end

    ::continue::
  end

  return top_items
end

-- ##############################################

-- List all the data series matching the given filter.
-- Only data series updated after start_time will be returned.
-- Returns a list of expanded tags based on the matches.
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

  for tag in pairs(schema.tags) do
    if not tags_filter[tag] then
      wildcard_tags[#wildcard_tags + 1] = tag
    end
  end

  return driver:listSeries(schema, tags_filter, wildcard_tags, start_time)
end

-- ##############################################

function ts_utils.exists(schema_name, tags_filter)
  return not table.empty(ts_utils.listSeries(schema_name, tags_filter, 0))
end

-- ##############################################

function ts_utils.flush()
  local rv = true

  for _, driver in pairs(ts_utils.listActiveDrivers()) do
    rv = driver:flush() and rv
  end

  return rv
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
