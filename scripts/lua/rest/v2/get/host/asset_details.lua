--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "mac_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local asset_utils = require "asset_utils"
local discover_utils = require "discover_utils"

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
local list = asset_utils.getInactiveHostInfo(ifid, serial_key) or {}

-- Check if at least an host is inactive
for _, host_details in pairs(list or {}) do

    local network_name = ""
    local json_info = host_details.json_info or {}
    
    -- Convert first and last seen to number
    local first_seen_ts = tonumber(host_details["first_seen"])
    local last_seen_ts = tonumber(host_details["last_seen"]) 
    local last_seen

    local first_seen = formatEpoch(first_seen_ts) .. " [" ..
                           secondsToTime(os.time() - first_seen_ts) .. " " .. i18n("details.ago") .. "]"

    -- Host is online if last_seen_ts is 0 
    if last_seen_ts == 0 then
        last_seen = "<span class='badge bg-success'>Online</span>"   
    else
        last_seen = formatEpoch(last_seen_ts) .. " [" ..
                          secondsToTime(os.time() - last_seen_ts) .. " " .. i18n("details.ago") .. "]"
    end

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
            name = discover_utils.devtype2icon(host_details["device_type"]) .. " " .. discover_utils.devtype2string(host_details["device_type"])
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

    -- Special formatted data
    local ip = host_details["ip"]

    -- Host is online, redirect to hosts page
    if last_seen_ts == 0 then
        ip = "<a href='/lua/host_details.lua?host=" .. ip .."' data-bs-toggle='tooltip' data-bs-placement='top' title='Host Details'> " .. ip .. " <i class='fas fa-laptop'></i></a>"        
    end
    
    if host_details["os_type"] then
        ip = ip .. " " .. discover_utils.getOsAndIcon(host_details["os_type"])
    end
    
    if host_details.is_dns_server then
        ip = ip .. " <span class='badge bg-success'>" .. i18n('asset_details.dns_server') .. "</span>"
    end
    if host_details.is_dhcp_server then
        ip = ip .. " <span class='badge bg-success'>" .. i18n('asset_details.dhcp_server') .. "</span>"
    end
    if host_details.is_smtp_server then
        ip = ip .. " <span class='badge bg-success'>" .. i18n('asset_details.smtp_server') .. "</span>"
    end
    if host_details.is_ntp_server then
        ip = ip .. " <span class='badge bg-success'>" .. i18n('asset_details.ntp_server') .. "</span>"
    end
    if host_details.is_imap_server then
        ip = ip .. " <span class='badge bg-success'>" .. i18n('asset_details.imap_server') .. "</span>"
    end
    if host_details.is_pop_server then
        ip = ip .. " <span class='badge bg-success'>" .. i18n('asset_details.pop_server') .. "</span>"
    end

    rsp["host_info"][#rsp["host_info"] + 1] = {
        name = i18n("ip_address_network"),
        values = {{
            name = ip
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

    if table.len(host_details.names) > 0 then
        rsp["host_info"][#rsp["host_info"] + 1] = {
            name = i18n("details.further_host_names_information"),
            values = {{
                name = "<b>" .. i18n("details.source") .."</b>"
            },{
                name = "<b>" .. i18n("name") .."</b>"
            }}
        }
        for type, name in pairs(host_details.names) do
            rsp["host_info"][#rsp["host_info"] + 1] = {
                values = {{
                    name = i18n("asset_details." .. type)
                },{
                    name = name
                }}
            }
        end
    end

    -- Now add the info inside the json_info
    for name, value in pairs(json_info or {}) do
        local formatted_name = i18n('asset_details.' .. name)
        if isEmptyString(formatted_name) then
            formatted_name = name
        end
        rsp["host_info"][#rsp["host_info"] + 1] = {
            name = formatted_name,
            values = {{
                name = value
            }}
        }
    end
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
