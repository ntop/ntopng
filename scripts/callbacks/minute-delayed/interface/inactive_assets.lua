--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "lua_utils"
local asset_management_utils = require "asset_management_utils"
local json = require ("dkjson")

-- #################################################################
-- Periodically fetches inactive host information from redis to add 
-- it to the slqlite database.
-- #################################################################

local start_time = os.time()  -- Record the start time
local duration = 40           -- Duration in seconds

local redis_key = string.format("ntopng.inactive_hosts_macs.queue.ifid_%d", interface.getId())

while os.difftime(os.time(), start_time) < duration and ntop.llenCache(redis_key) > 0 do
    local entry = json.decode(ntop.lpopCache(redis_key))

    if entry["type"] == "host" then
        asset_management_utils.insert_host(entry)
    else
        asset_management_utils.insert_mac(entry)
    end
end