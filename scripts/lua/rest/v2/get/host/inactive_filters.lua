--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "mac_utils"
local rest_utils = require "rest_utils"
local inactive_hosts_utils = require "inactive_hosts_utils"
local discover_utils = require "discover_utils"

if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

-- =============================

local ifid = _GET["ifid"]
local action = _GET["action"]

if isEmptyString(action) then
    return rest_utils.answer(rest_utils.consts.err.invalid_args)
end

local filters = {
    vlan = _GET["vlan_id"],
    network = _GET["network"],
    device_type = _GET["device_type"],
    manufacturer = _GET["manufacturer"],
}

-- Return the data
for filter, value in pairs(filters) do
    if isEmptyString(value) then
        filters[filter] = nil
    end
end

if not isEmptyString(ifid) then
    interface.select(ifid)
else
    ifid = interface.getId()
end

local network_filters = {}
local vlan_filters = {}
local device_filters = {}
local manufacturer_filters = {}

network_filters = inactive_hosts_utils.getNetworkFilters(ifid, filters)
vlan_filters = inactive_hosts_utils.getVLANFilters(ifid, filters)
device_filters = inactive_hosts_utils.getDeviceFilters(ifid, filters)
manufacturer_filters = inactive_hosts_utils.getManufacturerFilters(ifid, filters)

local rsp = {
    {
        action = "device_type",
        label = i18n("device"),
        tooltip = i18n("device_filter"),
        name = "device_filter",
        value = device_filters
    },
    {
        action = "manufacturer",
        label = i18n("manufacturer"),
        tooltip = i18n("manufacturer_filter"),
        name = "manufacturer_filter",
        value = manufacturer_filters
    },
    {
        action = "network",
        label = i18n("network"),
        tooltip = i18n("network_filter"),
        name = "network_filter",
        value = network_filters
    },
    {
        action = "vlan_id",
        label = i18n("vlan"),
        tooltip = i18n("vlan_filter"),
        name = "vlan_filter",
        value = vlan_filters
    },
}

rest_utils.answer(rest_utils.consts.success.ok, rsp)
