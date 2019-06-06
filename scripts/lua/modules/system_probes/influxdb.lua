--
-- (C) 2013-19 - ntop.org
--

local probe = {}

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local ts_utils = require("ts_utils")

-- ##############################################

function probe.isActive()
  return(ts_utils.getDriverName() == "influxdb")
end

-- ##############################################

function probe.loadSchemas(ts_utils)
  local schema

  -- TODO: can directly fetch from the InfluxDB data
  --[[
  schema = ts_utils.newSchema("influxdb:storage_size", {metrics_type = ts_utils.metrics.gauge})
  schema:addTag("database")
  schema:addMetric("storage_size")]]

  schema = ts_utils.newSchema("influxdb:rtt", {label = i18n("graphs.num_ms_rtt"), metrics_type = ts_utils.metrics.gauge})
  schema:addMetric("millis_rtt")
end

-- ##############################################

function probe.runMinuteTasks(when)
  local influxdb = ts_utils.getQueryDriver()
  local start_ms = ntop.gettimemsec()
  local res = influxdb:getInfluxdbVersion()

  if res ~= nil then
    local end_ms = ntop.gettimemsec()

    ts_utils.append("influxdb:rtt", {millis_rtt = ((end_ms-start_ms)*1000)}, when)
  end
end

-- ##############################################

return probe
