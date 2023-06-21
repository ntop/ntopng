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
local vlan_id = _GET["vlan_id"]
local network = _GET["network"]

if not isEmptyString(ifid) then
    interface.select(ifid)
else
    ifid = interface.getId()
end

if isEmptyString(action) then
    return rest_utils.answer(rest_utils.consts.err.invalid_args)
end

local network_filters = {}
local vlan_filters = {}

network_filters = inactive_hosts_utils.getNetworkFilters(ifid)
vlan_filters = inactive_hosts_utils.getVLANFilters(ifid)

local rsp = {
    {
        action = "vlan_id",
        label = i18n("vlan"),
        tooltip = i18n("vlan_filter"),
        name = "vlan_filter",
        value = vlan_filters
    },
    {
        action = "network",
        label = i18n("network"),
        tooltip = i18n("network_filter"),
        name = "network_filter",
        value = network_filters
    },
}

rest_utils.answer(rest_utils.consts.success.ok, rsp)
