--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "mac_utils"
local rest_utils = require "rest_utils"
local asset_management_utils = require "asset_management_utils"

if not _GET["serial_key"] then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

-- =============================

local ifid = _GET["ifid"]

if not isEmptyString(ifid) then
    interface.select(ifid)
else
    ifid = interface.getId()
end

local rsp = {
    host_name = "",
    host_info = {}
}
local serial_key = _GET["serial_key"]
local list = asset_management_utils.get_inactive_host_info(ifid, serial_key) or {}

-- Check if at least an host is inactive
for _, host_details in pairs(list or {}) do
    require "mac_utils"
    local discover_utils = require "discover_utils"
    local network_name = ""
    local first_seen = formatEpoch(host_details["first_seen"]) .. " [" ..
                           secondsToTime(os.time() - host_details["first_seen"]) .. " " .. i18n("details.ago") .. "]"
    local last_seen = formatEpoch(host_details["last_seen"]) .. " [" ..
                          secondsToTime(os.time() - host_details["last_seen"]) .. " " .. i18n("details.ago") .. "]"
    local url

    rsp["host_name"] = host_details["name"]

    if isEmptyString(rsp["host_name"]) then
        rsp["host_name"] = host_details["ip"]
    end

    -- If available, add url and extra info
    if interface.getMacInfo(host_details["mac"]) then
        url = mac2url(host_details["mac"])
    end

    rsp["host_info"][#rsp["host_info"] + 1] = {
        name = i18n("mac_address_dev_type"),
        values = {{
            name = mac2label(host_details["mac"]),
            url = url
        }, {
            name = discover_utils.devtype2string(host_details["device_type"])
        }}
    }

    url = nil

    rsp["host_info"][#rsp["host_info"] + 1] = {
        name = i18n("details.first_last_seen"),
        values = {{
            name = first_seen
        }, {
            name = last_seen
        }}
    }

    local network_stats = interface.getNetworkStats(tonumber(host_details["network"]))
    for key, _ in pairs(network_stats or {}) do
        url = '/lua/hosts_stats.lua?network=' .. host_details.network
        network_name = getFullLocalNetworkName(key)
    end

    rsp["host_info"][#rsp["host_info"] + 1] = {
        name = i18n("ip_address_network"),
        values = {{
            name = host_details["ip"]
        }, {
            name = network_name,
            url = url
        }}
    }

    local name = host_details["name"]
    if isEmptyString(name) then
        name = host_details["ip"]
    end

    rsp["host_info"][#rsp["host_info"] + 1] = {
        name = i18n("name"),
        values = {{
            name = name
        }}
    }
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
