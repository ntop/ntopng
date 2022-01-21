--
-- (C) 2019-21 - ntop.org
--

local redis_api = {}

-- ##############################################

local function getRedisStatus()
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
function redis_api.getStats()
    local redis_status = getRedisStatus()

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

-- ###############################################

function redis_api.redisTimeseriesEnabled()
    return(ntop.getPref("ntopng.prefs.system_probes_timeseries") ~= "0")
end

-- ###############################################

return redis_api
