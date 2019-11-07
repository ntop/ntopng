--
-- (C) 2013-19 - ntop.org
--

local ts_utils = require("ts_utils_core")

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

   -- Cache
   schema = ts_utils.newSchema("redis:hits", {metrics_type = ts_utils.metrics.gauge})
   schema:addTag("ifid")
   schema:addTag("command")
   schema:addMetric("num_calls")
end

-- ##############################################

function probe.getTimeseriesMenu(ts_utils)
   local menu = {
      {schema = "redis:memory", label = i18n("about.ram_memory")},
      {schema = "redis:keys", label = i18n("system_stats.redis.redis_keys")},
      {separator=1, label=i18n("system_stats.redis.commands")},
   }

   -- Populate individual commands timeseries
   local series = ts_utils.listSeries("redis:hits", {ifid = getSystemInterfaceId()}, 0)

   if(series) then
      for _, serie in pairsByField(series, "command", asc) do
	 menu[#menu + 1] = {
	    schema = "redis:hits",
	    label = i18n("system_stats.redis.command_hits", {cmd = string.upper(string.sub(serie.command, 5))}),
	    extra_params = {redis_command = serie.command},
	    metrics_labels = {i18n("graphs.num_calls")},
	 }
      end
   end

   return(menu)
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
   local hits_key = "ntopng.cache.redis.stats"
   local json = require("dkjson")
   local old_hits_stats = ntop.getCache(hits_key)
   local hits_stats = ntop.getCacheStats()

   if(not isEmptyString(old_hits_stats)) then
      old_hits_stats = json.decode(old_hits_stats) or {}
   else
      old_hits_stats = {}
   end

   ts_utils.append("redis:memory", {ifid = ifid, resident_bytes = stats["memory"]}, when)
   ts_utils.append("redis:keys", {ifid = ifid, num_keys = stats["dbsize"]}, when)

   for key, val in pairs(hits_stats) do
      if(old_hits_stats[key] ~= nil) then
	 local delta = math.max(val - old_hits_stats[key], 0)

	 -- Dump the delta value as a gauge
	 ts_utils.append("redis:hits", {ifid = ifid, command = key, num_calls = delta}, when)
      end
   end

   ntop.setCache(hits_key, json.encode(hits_stats))
end

-- ##############################################

return probe
