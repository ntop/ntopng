--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "check_redis_prefs"
local json = require "dkjson"
local asset_utils = require "asset_utils"

-- #################################################################
-- Periodically fetches inactive host information from redis to add 
-- it to the slqlite database.
-- #################################################################

local start_time = os.time()  -- Record the start time
local duration = 40           -- Duration in seconds
local ifid = interface.getId()
local version = 0
local redis_key = string.format("ntopng.assets_hosts_macs.queue.ifid_%d", ifid)
local num_keys = ntop.llenCache(redis_key)

if num_keys > 0 then
    if hasClickHouseSupport() then
        version = asset_utils.getLastVersion(ifid)
        version = tonumber(version or 0) + 1
    end

    while os.difftime(os.time(), start_time) < duration and num_keys > 0 do
        local entry = ntop.lpopCache(redis_key)

        if entry then
            entry = json.decode(entry) or {}
            if entry and entry["type"] == "host" then
                asset_utils.insertHost(entry, version, ifid)
            elseif entry and entry["type"] == "mac" then
                asset_utils.insertMac(entry, version, ifid)
            end
            version = version + 1
        end
        num_keys = num_keys - 1
    end
end