--
-- (C) 2013-19 - ntop.org
--

local ts_utils = require("ts_utils_core")
local alerts = require("alerts_api")

local MAX_INFLUX_EXPORT_QUEUE_LEN = 30

local probe = {
  name = "InfluxDB",
  description = "Monitors InfluxDB health and performance",
  page_script = "influxdb_stats.lua",
  page_order = 1600,
}

-- ##############################################

local function get_memory_size_query(influxdb, schema, tstart, tend, time_step)
  --[[
     See comments in function driver:getMemoryUsage() to understand
     why it is necessary to subtract the HeapReleased from Sys.
  --]]
  local q = 'SELECT MEAN(Sys) - MEAN(HeapReleased) as mem_bytes' ..
      ' FROM "_internal".."runtime"' ..
      " WHERE time >= " .. tstart .. "000000000 AND time <= " .. tend .. "000000000" ..
      " GROUP BY TIME(".. time_step .."s)"

  return(q)
end

local function get_write_success_query(influxdb, schema, tstart, tend, time_step)
  local q = 'SELECT SUM(writePointsOk) as points' ..
      ' FROM (SELECT '..
      ' (DERIVATIVE(MEAN(writePointsOk)) / '.. time_step ..') as writePointsOk' ..
      ' FROM "monitor"."shard" WHERE "database"=\''.. influxdb.db ..'\'' ..
      " AND time >= " .. tstart .. "000000000 AND time <= " .. tend .. "000000000" ..
      " GROUP BY id)" ..
      " GROUP BY TIME(".. time_step .."s)"

  return(q)
end

-- ##############################################

function probe.isEnabled()
  return(ts_utils.getDriverName() == "influxdb")
end

-- ##############################################

function probe.loadSchemas(ts_utils)
  local schema

  schema = ts_utils.newSchema("influxdb:storage_size", {
    metrics_type = ts_utils.metrics.gauge,
  })
  schema:addTag("ifid")
  schema:addMetric("disk_bytes")

  schema = ts_utils.newSchema("influxdb:exported_points",
    {metrics_type = ts_utils.metrics.counter})
  schema:addTag("ifid")
  schema:addMetric("points")

  schema = ts_utils.newSchema("influxdb:dropped_points",{metrics_type = ts_utils.metrics.counter})
  schema:addTag("ifid")
  schema:addMetric("points")

  schema = ts_utils.newSchema("influxdb:exports", {metrics_type = ts_utils.metrics.counter})
  schema:addTag("ifid")
  schema:addMetric("num_exports")

  schema = ts_utils.newSchema("influxdb:rtt", {metrics_type = ts_utils.metrics.gauge})
  schema:addTag("ifid")
  schema:addMetric("millis_rtt")

  -- The following metrics are built-in into influxdb
  schema = ts_utils.newSchema("influxdb:memory_size", {
    influx_internal_query = get_memory_size_query,
    metrics_type = ts_utils.metrics.gauge, step = 10
  })
  schema:addTag("ifid")
  schema:addMetric("mem_bytes")

  schema = ts_utils.newSchema("influxdb:write_successes", {
    influx_internal_query = get_write_success_query,
    metrics_type = ts_utils.metrics.counter, step = 10
  })
  schema:addTag("ifid")
  schema:addMetric("points")
end

-- ##############################################

function probe.getTimeseriesMenu(ts_utils)
  local influxdb = ts_utils.getQueryDriver()

  return {
    {schema="influxdb:storage_size",                      label=i18n("traffic_recording.storage_utilization")},
    {schema="influxdb:memory_size",                       label=i18n("about.ram_memory")},
    {schema="influxdb:write_successes",                   label=i18n("system_stats.write_througput")},
    {schema="influxdb:exports",                           label=i18n("system_stats.exports_label"),
      value_formatter = {"export_rate", "exports_format"},
      metrics_labels = {i18n("system_stats.exports_label")}},
    {schema="influxdb:exported_points",                   label=i18n("system_stats.exported_points")},
    {schema="influxdb:dropped_points",                    label=i18n("system_stats.dropped_points")},
    {schema="custom:infludb_exported_vs_dropped_points",  label=i18n("system_stats.exported_vs_dropped_points"),
      custom_schema = {
        bases = {"influxdb:exported_points", "influxdb:dropped_points"},
        types = {"area", "line"}, axis = {1,2},
      },
      metrics_labels = {i18n("system_stats.exported_points"), i18n("system_stats.dropped_points")},
    },
    {schema="influxdb:rtt",                               label=i18n("graphs.num_ms_rtt")},
  }
end

-- ##############################################

function probe.getExportStats()
  local points_exported = 0
  local points_dropped = 0
  local exports = 0
  local ifnames = interface.getIfNames()

  local influxdb = ts_utils.getQueryDriver()

  for ifid, ifname in pairs(ifnames) do
     points_exported = points_exported + influxdb:get_exported_points(ifid)
     points_dropped = points_dropped + influxdb:get_dropped_points(ifid)
     exports = exports + influxdb:get_exports(ifid)
  end

  local res = {
     health = influxdb:get_health(),
     points_exported = points_exported,
     points_dropped = points_dropped,
     exports = exports,
  }

  return(res)
end

-- ##############################################

function probe._measureRtt(when, ts_utils, influxdb)
  local start_ms = ntop.gettimemsec()
  local res = influxdb:getInfluxdbVersion()
  local ifid = getSystemInterfaceId()

  if res ~= nil then
    local end_ms = ntop.gettimemsec()

    ts_utils.append("influxdb:rtt", {ifid = ifid, millis_rtt = ((end_ms-start_ms)*1000)}, when)
  end
end

-- ##############################################

function probe._exportStats(when, ts_utils, influxdb)
  local stats = probe.getExportStats()
  local ifid = getSystemInterfaceId()

  ts_utils.append("influxdb:exported_points", {ifid = ifid, points = stats.points_exported}, when)
  ts_utils.append("influxdb:dropped_points", {ifid = ifid, points = stats.points_dropped}, when)
  ts_utils.append("influxdb:exports", {ifid = ifid, num_exports = stats.exports}, when)
end

-- ##############################################

function probe._exportStorageSize(when, ts_utils, influxdb)
  local disk_bytes = influxdb:getDiskUsage()
  local ifid = getSystemInterfaceId()

  if(disk_bytes ~= nil) then
    ts_utils.append("influxdb:storage_size", {ifid = ifid, disk_bytes = disk_bytes}, when)
  end
end

-- ##############################################

function probe.runTask(when, ts_utils)
  local influxdb = ts_utils.getQueryDriver()

  probe._exportStats(when, ts_utils, influxdb)
  probe._measureRtt(when, ts_utils, influxdb)
  probe._exportStorageSize(when, ts_utils, influxdb)
end

-- ##############################################

return probe
