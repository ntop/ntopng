--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_dump = require "ts_min_dump_utils"
local ts_utils = require("ts_utils_core")
local checks = require("checks")
local json = require("dkjson")
local redis_api = require "redis_api"

local ifid = getSystemInterfaceId()
local hits_key = "ntopng.cache.redis.stats"
local hits_stats = ntop.getCacheStats()
local old_hits_stats = ntop.getCache(hits_key)
 
-- ##############################################

if redis_api.redisTimeseriesEnabled() then
    local stats = redis_api.getStats()

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

            -- Dump the delta value as a gauge
            ts_utils.append("redis:hits", {ifid = ifid, command = key, num_calls = delta}, when)
        end
    end

    ntop.setCache(hits_key, json.encode(hits_stats))
end

