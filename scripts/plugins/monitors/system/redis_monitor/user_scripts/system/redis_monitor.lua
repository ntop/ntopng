--
-- (C) 2019-20 - ntop.org
--

local ts_utils = require("ts_utils_core")
local user_scripts = require("user_scripts")

local script = {
  -- Script category
  category = user_scripts.script_categories.system,

  -- This module is enabled by default
  default_enabled = true,

  -- No default configuration is provided
  default_value = {},

  -- See below
  hooks = {},

  gui = {
    i18n_title = "system_stats.redis.redis_monitor",
    i18n_description = "system_stats.redis.redis_monitor_description",
  },
}

-- ##############################################

-- Defines an hook which is executed every minute
function script.hooks.min(params)
   if params.ts_enabled then
      local ifid = getSystemInterfaceId()
      local stats = script.getStats()
      local hits_key = "ntopng.cache.redis.stats"
      local json = require("dkjson")
      local hits_stats = ntop.getCacheStats()

      local old_hits_stats = ntop.getCache(hits_key)

      if(not isEmptyString(old_hits_stats)) then
	 old_hits_stats = json.decode(old_hits_stats) or {}
      else
	 old_hits_stats = {}
      end

      if stats["memory"] then
         ts_utils.append("redis:memory", {ifid = ifid, resident_bytes = stats["memory"]}, when)
      end

      if stats["dbsize"] then
         ts_utils.append("redis:keys", {ifid = ifid, num_keys = stats["dbsize"]}, when)
      end

      for key, val in pairs(hits_stats) do
	 if(old_hits_stats[key] ~= nil) then
	    local delta = math.max(val - old_hits_stats[key], 0)

	    -- Dump the delta value as a gauge
	    ts_utils.append("redis:hits", {ifid = ifid, command = key, num_calls = delta}, when)
	 end
      end

      ntop.setCache(hits_key, json.encode(hits_stats))
   end
end

-- ##############################################

function script.getRedisStatus()
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

   if ntop.isWindows() then
      -- See Windows note in script.getStats()
      return health
   end

   if redis_status["aof_enabled"] and redis_status["aof_enabled"] ~= 0 then
      -- If here the use of Redis Append Only File (AOF) is enabled
      -- so we should check for its errors
      if redis_status["aof_last_bgrewrite_status"] ~= "ok" or redis_status["aof_last_write_status"] ~= "ok" then
	 health = "red"
      end
   end

   if redis_status["rdb_last_bgsave_status"] ~= "ok" then
      health = "red"
   end

   return health
end

-- ##############################################

-- NOTE: on Windows, some stats are missing from script.getRedisStatus():
--    - aof_last_bgrewrite_status
--    - aof_last_write_status
--    - rdb_last_bgsave_status
--    - dbsize
function script.getStats()
   local redis_status = script.getRedisStatus()

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

return(script)
