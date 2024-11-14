--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "mac_utils"
local rest_utils = require "rest_utils"
local discover_utils = require "discover_utils"
local asset_management_utils = require "asset_management_utils"

if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

-- =============================

local ifid = _GET["ifid"] or interface.getId()

local available_filters = asset_management_utils.get_filters(ifid)
local rsp = {}
local filters = {}

for _, value in pairs(available_filters or {}) do
    if not filters[value.filter] then
        filters[value.filter] = {}
    end

    filters[value.filter][value.value] = value.count
end

for key, value in pairsByKeys(filters or {}, asc) do
    local filter_list = {{
        key = key,
        value = "",
        label = i18n("all")
    }}

    local formatter
    if key == "vlan" then
        formatter = getFullVlanName
    elseif key == "device_type" then
        formatter = discover_utils.devtype2string
    end
    for name, count in pairsByKeys(value or {}) do
        local value = name
        if isEmptyString(value) then
           goto continue 
        end
        if tonumber(name) then
            value = tonumber(name)
        end
        if formatter then
            name = formatter(name)
            if isEmptyString(name) then
                name = value
            end
        elseif key == "network" then -- special case
            local stats = interface.getNetworkStats(tonumber(name))
            local net_key
            for key, _ in pairs(stats or {}) do
                net_key = key
                break
            end
            name = getFullLocalNetworkName(net_key)
        end
        filter_list[#filter_list + 1] = {
            key = key,
            value = value,
            label = name,
            count = count
        }

        ::continue::
    end

    rsp[#rsp + 1] = {
        action = key,
        label = i18n(key),
        name = key,
        value = filter_list
    }
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
