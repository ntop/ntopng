--
-- (C) 2019-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local radius_handler = require "radius_handler"

-- #################################################################

if radius_handler.isAccountingEnabled() then
    -- TODO: currently accounting is supported only for an interface
    --       add the support to multiple interfaces
    interface.select(tostring(interface.getFirstInterfaceId()))
    local keys = radius_handler.getAllKeys()
    for _, member in pairs(keys) do
        local mac_info = interface.getMacInfo(member)
        if not mac_info then
            -- In case the MAC is not connected, call the stop
            radius_handler.accountingStop(member)
        end
    end

    interface.select("-1") -- System Interface
end
