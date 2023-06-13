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

if not isEmptyString(ifid) then
    interface.select(ifid)
else
    ifid = interface.getId()
end

local rsp = {}
local hosts = inactive_hosts_utils.getInactiveHosts(ifid)

-- Check if at least an host is inactive
if table.len(hosts) > 0 then
    local format_utils = require("format_utils")
    local start = _GET["start"]
    local length = _GET["length"]
    local order_field = _GET["sort"] or "last_seen"
    local order

    if (_GET["order"]) and (_GET["order"] == "asc") then
        order = asc
    else
        order = rev
    end

    -- Sorting the table
    table.sort(hosts, function(x, y)
        return order(x[order_field], y[order_field])
    end)

    -- Cutting down the table
    for key, value in pairs({table.unpack(hosts, start + 1, start + length)}) do
        rsp[key] = value
    end

    -- Format the values to be used by the front end application
    for key, value in pairs(rsp) do
        rsp[key]["last_seen"] = format_utils.formatPastEpochShort(value["last_seen"])
        rsp[key]["first_seen"] = format_utils.formatPastEpochShort(value["first_seen"])
        rsp[key]["device_type"] = discover_utils.devtype2icon(value["device_id"]) .. " " .. value["device_type"]

        -- If available, add url and extra info
        local mac_info = interface.getMacInfo(value["mac_address"])
        if mac_info then
            rsp[key]["mac_address"] = {
                name = mac2label(value["mac_address"]),
                value = value["mac_address"],
                url = mac2url(value["mac_address"])
            }
            rsp[key]["mac_address_manufacturer"] = mac_info.manufacturer
        else 
            local mac_manufacturer = ntop.getMacManufacturer(value["mac_address"])
            if mac_manufacturer then
                rsp[key]["mac_address_manufacturer"] = mac_manufacturer.extended
            end
        end

        if interface.getNetworkStats(rsp[key]["network_id"]) then
            rsp[key]["network"] = {
                name = rsp[key]["network"],
                value = rsp[key]["network_id"],
                url = '/lua/hosts_stats.lua?network=' .. rsp[key]["network_id"]
            }
        end

        if interface.getVLANInfo(rsp[key]["vlan_id"]) then
            rsp[key]["vlan"] = {
                name = rsp[key]["vlan"],
                value = rsp[key]["vlan_id"],
                url = '/lua/hosts_stats.lua?vlan=' .. rsp[key]["vlan_id"]
            }
        end

        rsp[key]["ip_address"] = {
            name = rsp[key]["ip_address"],
            value = rsp[key]["ip_address"],
            url = '/lua/inactive_host_details.lua?serial_key=' .. rsp[key]["serial_key"]
        }
        rsp[key]["device_id"] = nil
        rsp[key]["network_id"] = nil
        rsp[key]["vlan_id"] = nil
    end
end

rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
    ["recordsTotal"] = #hosts
})
