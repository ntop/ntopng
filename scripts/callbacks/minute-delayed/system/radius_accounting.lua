--
-- (C) 2019-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local radius_handler = require "radius_handler"

-- #################################################################

if radius_handler.isAccountingEnabled() then
    -- Import only if radius is enabled, otherwise it's a waste of memory
    require "lua_utils"
    local host_pools = require "host_pools"

    -- Instantiate host pools
    local pool = host_pools:create()
    local pools_list = {}

    -- Table with pool names as keys
    for _, pool_info in pairs(pool:get_all_pools()) do
        pools_list[pool_info["name"]] = pool_info
    end

    -- TODO: currently accounting is supported only for an interface
    --       add the support to multiple interfaces
    interface.select(tostring(interface.getFirstInterfaceId()))

    for _, pool_info in pairs(pools_list) do
        if pool_info.id ~= host_pools.DEFAULT_POOL_ID and pool_info.id ~= host_pools.DROP_HOST_POOL_ID then
            local members = pool_info.members

            for _, member in pairs(members) do
                local is_mac = isMacAddress(member)
                if is_mac then
                    -- Update stats only if the mac is in memory
                    local mac_info = interface.getMacInfo(member)
                    if mac_info then
                        -- In case the update fails, move the member into the default pool
                        radius_handler.accountingUpdate(member, mac_info)
                    end
                end
            end
        end
    end

    interface.select("-1") -- System Interface
end
