--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/schemas/?.lua;" .. package.path

-- Import ntop_utils instead of lua_utils, it's a lot lighter
require "ntop_utils"
local redis_api = require "redis_api"

local ifid = getSystemInterfaceId()
local hits_key = "ntopng.cache.redis.stats"
local hits_stats = ntop.getCacheStats()
local old_hits_stats = ntop.getCache(hits_key)
 
-- ##############################################
local read_op = {
    num_get = true,
    num_hget = true,
    num_hgetall = true,
    num_hkeys = true,
    num_llen = true,
    num_lpop_rpop = true,
    num_strlen = true,
    num_ttl = true,
    num_resolver_get_address = true
}

local write_op = {
    num_set = true,
    num_hset = true,
    num_lpush_rpush = true,
    num_trim = true,
    num_del = true,
    num_hdel = true,
    num_expire = true,
    num_resolver_set_address = true
}

if redis_api.redisTimeseriesEnabled() then
    require "ts_minute"
    -- Include only here, otherwise it's a useless import
    local json = require("dkjson")
    local ts_utils = require("ts_utils_core")

    local when = os.time()
    local stats = redis_api.getStats()
    
    local reads = 0
    local writes = 0
    
    if(not isEmptyString(old_hits_stats)) then
        old_hits_stats = json.decode(old_hits_stats) or {}
    else
        old_hits_stats = {}
    end

    if stats["memory"] then
        ts_utils.append("redis:memory", { ifid = ifid, resident_bytes = stats["memory"] }, when)
    end

    if stats["dbsize"] then
        ts_utils.append("redis:keys", {ifid = ifid, num_keys = stats["dbsize"]}, when)
    end

    for key, val in pairs(hits_stats) do
        if(old_hits_stats[key] ~= nil) then
            local delta = math.max(val - old_hits_stats[key], 0)
            if read_op[key] then
                reads=reads+delta
            elseif write_op[key] then
                writes=writes+delta
            end
            -- Dump the delta value as a gauge
            ts_utils.append("redis:hits", {ifid = ifid, command = key, num_calls = delta}, when)
        end
    end
    
    ts_utils.append("redis:reads_writes_v2", {ifid = ifid, num_reads = reads, num_writes = writes}, when)

    ntop.setCache(hits_key, json.encode(hits_stats))
end