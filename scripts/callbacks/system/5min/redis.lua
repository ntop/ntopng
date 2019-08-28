--
-- (C) 2013-19 - ntop.org
--

local ts_utils = require("ts_utils_core")
local alerts = require("alerts_api")

local probe = {
   name = "Redis",
   description = "Monitors Redis health and performance",
   page_script = "redis_stats.lua",
   page_order = 1700,
}

-- ##############################################

function probe.isEnabled()
   return true
end

-- ##############################################

function probe.loadSchemas(ts_utils)
   local schema

   schema = ts_utils.newSchema("redis:storage_size", {
				  metrics_type = ts_utils.metrics.gauge,
   })
   schema:addTag("ifid")
   schema:addMetric("disk_bytes")
end

-- ##############################################

function probe.getTimeseriesMenu(ts_utils)
   return {
      {schema = "redis:storage_size", label = i18n("traffic_recording.storage_utilization")},
   }
end

-- ##############################################

function probe.getRedisInfo()
   local redis_info = ntop.getCacheInfo()
   local res = {}

   for _, k in pairs(redis_info:split("\r\n")) do
      local k = k:split(":")

      if k then
	 local v_k = k[1]
	 local v = tonumber(k[2]) or k[2]

	 res[v_k] = v
      end
   end

   return res
end

-- ##############################################

function probe.getStats()
   local redis_info = probe.getRedisInfo()
   local res = {
      -- used_memory_rss: Number of bytes that Redis allocated
      -- as seen by the operating system (a.k.a resident set size).
      -- This is the number reported by tools such as top(1) and ps(1)
      memory = redis_info["used_memory_rss"]
   }

   return res
end

-- ##############################################

function probe._exportStorageSize(when, ts_utils, influxdb)
   local disk_bytes = 0
   local ifid = getSystemInterfaceId()

   if disk_bytes then
      ts_utils.append("redis:storage_size", {ifid = ifid, disk_bytes = disk_bytes}, when)
   end
end

-- ##############################################

function probe.runTask(when, ts_utils)
   probe._exportStorageSize(when, ts_utils, influxdb)
end

-- ##############################################

return probe
