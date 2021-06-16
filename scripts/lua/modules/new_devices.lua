--
-- (C) 2013-21 - ntop.org
--

require "lua_utils"
local sys_utils = require "sys_utils"
local rest_utils = require("rest_utils")

local new_devices = {}

local redis_key = "ntopng.cache.checks.unexpected_new_device_plugins_enabled"

-- ################################################################

function new_devices.reset_macs() 
    local getIfNames = interface.getIfNames()

    for key, value in pairs(getIfNames) do
        -- Retrieving the if id 
        --local ifid = value.getId()

        local seen_devices_hash = getFirstSeenDevicesHashKey(key)
        -- Retrieving the list of the addresses already seen
        local seen_devices = ntop.getHashAllCache(seen_devices_hash) or {}

        for key, value in pairs(seen_devices) do
            ntop.delHashCache(seen_devices_hash, key)
            ntop.delCache(redis_key .. "." .. key)
        end
    end    

    rest_utils.answer(rest_utils.consts.success.ok)
end

-- #################################

return new_devices