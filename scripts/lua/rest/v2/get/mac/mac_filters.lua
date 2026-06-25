--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" ..
                   package.path

require "label_utils"
require "lua_utils_gui"
require "http_lint"
require "lua_utils_get"
local discover = require "discover_utils"
local rest_utils = require "rest_utils"
local rsp = {}

local manufacturers = interface.getMacManufacturers()
if table.len(manufacturers) > 1 then
    local manufacturer_filters = {{key = "manufacturer", value = "", label = i18n("all")}}
    local tmp_list = {}
    for manufacturer, total in pairs(manufacturers) do
        tmp_list[manufacturer] = {
            key = "manufacturer",
            value = manufacturer,
            label = manufacturer
        }
    end
     for _, value in pairsByKeys(tmp_list, asc) do
        manufacturer_filters[#manufacturer_filters + 1] = value
    end

    rsp[#rsp + 1] = {
        action = "manufacturer",
        label = i18n("manufacturer"),
        name = "manufacturer",
        value = manufacturer_filters
    }
end

local device_types = interface.getMacDeviceTypes()
if table.len(device_types) > 1 then
    local device_type_filters = {{key = "device_type", value = "", label = i18n("all")}}
    local tmp_list = {}
    for device_type, total in pairs(device_types) do
        tmp_list[device_type] = {
            key = "device_type",
            value = device_type,
            label = discover.devtype2string(device_type)
        }
    end
     for _, value in pairsByKeys(tmp_list, asc) do
        device_type_filters[#device_type_filters + 1] = value
    end

    rsp[#rsp + 1] = {
        action = "device_type",
        label = i18n("device_type"),
        name = "device_type",
        value = device_type_filters
    }
end

if ntop.isnEdge and ntop.isnEdge() then
    local location_list = {
        {
            key = "location",
            value = "all",
            label = i18n('hosts_stats.all')
        },
        {
            key = "location",
            value = "wan",
            label = i18n('nedge.wan')
        },
        {
            key = "location",
            value = "lan",
            label = i18n('nedge.lan')
        },
        {
            key = "location",
            value = "unknown",
            label = i18n('unknown')
        }
    }
    
    rsp[#rsp + 1] = {
        action = "location",
        label = i18n("hosts_stats.location"),
        name = "location",
        value = location_list
    }
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
