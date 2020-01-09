--
-- (C) 2019-20 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

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

schema = ts_utils.newSchema("influxdb:storage_size", {
      metrics_type = ts_utils.metrics.gauge,
      is_system_schema = true,
      step = 300,
})
schema:addTag("ifid")
schema:addMetric("disk_bytes")

schema = ts_utils.newSchema("influxdb:exported_points", {
      metrics_type = ts_utils.metrics.counter,
      is_system_schema = true,
      step = 300,
})
schema:addTag("ifid")
schema:addMetric("points")

schema = ts_utils.newSchema("influxdb:dropped_points", {
      metrics_type = ts_utils.metrics.counter,
      is_system_schema = true,
      step = 300,
})
schema:addTag("ifid")
schema:addMetric("points")

schema = ts_utils.newSchema("influxdb:exports", {
      metrics_type = ts_utils.metrics.counter,
      is_system_schema = true,
      step = 300,
})
schema:addTag("ifid")
schema:addMetric("num_exports")

schema = ts_utils.newSchema("influxdb:rtt", {
      metrics_type = ts_utils.metrics.gauge,
      is_system_schema = true,
      step = 300,
})
schema:addTag("ifid")
schema:addMetric("millis_rtt")

-- The following metrics are built-in into influxdb
schema = ts_utils.newSchema("influxdb:memory_size", {
      influx_internal_query = get_memory_size_query,
      is_system_schema = true,
      metrics_type = ts_utils.metrics.gauge,
      step = 10,
})
schema:addTag("ifid")
schema:addMetric("mem_bytes")

schema = ts_utils.newSchema("influxdb:write_successes", {
      influx_internal_query = get_write_success_query,
      is_system_schema = true,
      metrics_type = ts_utils.metrics.counter,
      step = 10,
})
schema:addTag("ifid")
schema:addMetric("points")
