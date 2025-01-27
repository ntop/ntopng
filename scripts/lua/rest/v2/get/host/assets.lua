--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "label_utils"
require "ntop_utils"
require "http_lint"
require "lua_utils_get"
local format_utils = require "format_utils"
local rest_utils = require "rest_utils"
local asset_utils = require "asset_utils"

local ifid = _GET["ifid"] or interface.getId()
local start = _GET["start"] or 0
local length = _GET["length"] or 0
local sort = _GET["sort"] or "ip_address"
local order = _GET["order"] or "desc"
local rsp = {}

local gui_to_db_columns = {
    ip_address = "ip",
    host_name = "name",
    mac = "mac",
    vlan = "vlan",
    network = "network",
    device_type = "device_type",
    manufacturer = "manufacturer",
    first_seen = "first_seen",
    last_seen = "last_seen",
    device_status = "device_status",
}

if sort == "status" then
    -- The status sorting is pretty much the last_seen sorting
    sort = "last_seen"
end

local filters = {
    manufacturer = _GET["manufacturer"],
    vlan = _GET["vlan"],
    device_type = _GET["device_type"],
    network = _GET["network"],
    status = _GET["status"]
}
for key, value in pairs(filters) do
    if isEmptyString(value) then
        filters[key] = nil
    end
end

local tot_assets = asset_utils.getNumAssets(ifid, filters)[1].count
local assets = asset_utils.getHostsAssets(ifid, order, gui_to_db_columns[sort], start, length, filters)

for _, value in pairs(assets or {}) do
    local record = {}

    local column_ip = {
        ip = value.ip
    }
    if not isEmptyString(value.os) then
        column_ip.os = tonumber(value.os)
    end
    if value["systemhost"] then
        column_ip.system_host = true
    end
    if value["hiddenFromTop"] then
        column_ip.hidden_from_top = true
    end
    if value["childSafe"] then
        column_ip.child_safe = true
    end
    if value["dhcpHost"] then
        column_ip.dhcp_host = true
    end
    if value["device_type"] then
        column_ip.device_type = value["device_type"]
    end
    if value["country"] then
        column_ip.country = value["country"]
    end
    if value["is_blacklisted"] then
        column_ip.is_blacklisted = value["is_blacklisted"]
    end
    if value["crawlerBotScannerHost"] then
        column_ip.crawler_bot_scanner_host = value["crawlerBotScannerHost"]
    end
    column_ip.localhost = true
    if value["is_blackhole"] then
        column_ip.is_blackhole = value["is_blackhole"]
    end

    column_ip["vlan"] = {
        name = '',
        id = 0
    }

    if not isEmptyString(value["vlan"]) then
        column_ip["vlan"]["name"] = getFullVlanName(value["vlan"])
        column_ip["vlan"]["id"] = value["vlan"]
    end

    record.host_name = {
        alt_name = "",
        name = value["name"]
    }

    local alt_name = getHostAltName(value["ip"])
    if not isEmptyString(alt_name) then
        record.hostname.alt_name = alt_name
    end

    local in_memory_mac = false
    if interface.getMacInfo(value["mac"]) then
        in_memory_mac = true
    end

    record["mac"] = {
        value = value["mac"],
        name = getDeviceName(value["mac"]),
        is_in_memory = in_memory_mac
    }

    record["host"] = column_ip
    record["first_seen"] = {
        date = format_utils.formatPastEpochShort(value["first_seen"]),
        timestamp = value["first_seen"]
    }
    local last_seen = tonumber(value["last_seen"])
    local date = format_utils.formatPastEpochShort(last_seen)
    if last_seen == 0 then
        date = "-"
    end
    record["last_seen"] = {
        date = date,
        timestamp = last_seen
    }
    record["manufacturer"] = value["manufacturer"]
    record["key"] = value["key"]
    rsp[#rsp + 1] = record
end

rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
    ["recordsTotal"] = tonumber(tot_assets)
})
