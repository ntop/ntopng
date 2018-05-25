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

package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path

-----------------------------------------------------------------------

-- All the drivers

--TODO
local dirs = ntop.getDirs()
local rrd_driver = require("rrd"):new({base_path = (dirs.workingdir .. "/rrd_new")})
local influxdb_driver = nil

if not isEmptyString(ntop.getCache("ntopng.prefs.ts_post_data_url")) then
  influxdb_driver = require("influxdb"):new()
end

function ts_utils.listDrivers()
  --TODO
  return {rrd_driver, influxdb_driver}
end

-- Only active drivers
function ts_utils.listActiveDrivers()
  --TODO
  return {rrd_driver, influxdb_driver}
end

function ts_utils.enableDriver(driver)
  --TODO
end

function ts_utils.disableDriver(driver)
  --TODO
end

-----------------------------------------------------------------------

function ts_utils.append(schema, tags_and_metrics, timestamp, verbose)
  timestamp = timestamp or os.time()
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

function ts_utils.query(schema, tags, tstart, tend)
  if not schema:verifyTags(tags) then
    return false
  end

  driver = ts_utils.listActiveDrivers()[1]

  if not driver then
    return false
  end

  return driver:query(schema, tstart, tend, tags)
end

function ts_utils.flush()
  local rv = true

  for _, driver in pairs(ts_utils.listActiveDrivers()) do
    rv = driver:flush() and rv
  end

  return rv
end

function ts_utils.delete(schema, tags)
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
