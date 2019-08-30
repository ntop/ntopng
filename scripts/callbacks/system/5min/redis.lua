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

   schema = ts_utils.newSchema("redis:memory", {
				  metrics_type = ts_utils.metrics.gauge,
   })
   schema:addTag("ifid")
   schema:addMetric("resident_bytes")

   schema = ts_utils.newSchema("redis:keys", {
				  metrics_type = ts_utils.metrics.gauge,
   })
   schema:addTag("ifid")
   schema:addMetric("num_keys")
end

-- ##############################################

function probe.getTimeseriesMenu(ts_utils)
   return {
      {schema = "redis:memory", label = i18n("about.ram_memory")},
      {schema = "redis:keys", label = i18n("system_stats.redis.redis_keys")},
   }
end

-- ##############################################

function probe.getRedisStatus()
   local redis = ntop.getCacheStatus()
   local redis_info = redis["info"]
   local res = {}

   for _, k in pairs(redis_info:split("\r\n")) do
      local k = k:split(":")

      if k then
	 local v_k = k[1]
	 local v = tonumber(k[2]) or k[2]

	 res[v_k] = v
      end
   end


   if redis["dbsize"] then
      res["dbsize"] = redis["dbsize"]
   end

   return res
end

-- ##############################################

local function getHealth(redis_status)
   local health = "green"

   if redis_status["aof_enabled"] and redis_status["aof_enabled"] ~= 0 then
      -- If here the use of Redis Append Only File (AOF) is enabled
      -- so we should check for its errors
      if redis_stats["aof_last_bgrewrite_status"] ~= "ok" or redis_status["aof_last_write_status"] ~= "ok" then
	 health = "red"
      end
   end

   if redis_status["rdb_last_bgsave_status"] ~= "ok" then
      health = "red"
   end

   return health
end

-- ##############################################

function probe.getStats()
   local redis_status = probe.getRedisStatus()

   local res = {
      -- used_memory_rss: Number of bytes that Redis allocated
      -- as seen by the operating system (a.k.a resident set size).
      -- This is the number reported by tools such as top(1) and ps(1)
      memory = redis_status["used_memory_rss"],
      -- The number of keys in the database
      dbsize = redis_status["dbsize"],
      -- Health
      health = getHealth(redis_status)
   }

   return res
end

-- ##############################################

function probe.runTask(when, ts_utils)
   local ifid = getSystemInterfaceId()
   local stats = probe.getStats()

   ts_utils.append("redis:memory", {ifid = ifid, resident_bytes = stats["memory"]}, when)
   ts_utils.append("redis:keys", {ifid = ifid, num_keys = stats["dbsize"]}, when)
end

-- ##############################################

return probe
