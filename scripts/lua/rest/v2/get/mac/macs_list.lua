--
-- (C) 2013-25 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "label_utils"
require "ntop_utils"
require "http_lint"
require "mac_utils"
local discover = require "discover_utils"

local rest_utils = require "rest_utils"
local vs_utils = require "vs_utils"

-- Table parameters
local all = _GET["all"]
local sort_order = _GET["order"]
local devices_mode  = _GET["devices_mode"]
local manufacturer  = _GET["manufacturer"]
local device_type   = tonumber(_GET["device_type"])

function macHosts(mac)
    require "lua_utils_gui"
    local mac_hosts = interface.getMacHosts(mac)
    local num_hosts = table.len(mac_hosts)
    if num_hosts > 0 then
        local first_host

        for _, h in pairsByKeys(mac_hosts, asc) do
            first_host = h
            break
        end
        local host_label = first_host["ip"]
        return {host_label = host_label, num_hosts = num_hosts, has_name = false}
    end
    return {host_label='', num_hosts, has_name = false}
end

local c_order = true
local lua_order = asc
local throughput_type = getThroughputType()

if (sort_order == "desc") then
    lua_order = rev
    c_order = false
end

local source_macs_only   = false
local inactive_macs_only = false

if devices_mode == "source_macs_only" then
   source_macs_only = true
elseif devices_mode == "inactive_macs_only" then
   source_macs_only = true
   inactive_macs_only = true   		    
end

if manufacturer == "" then manufacturer = nil end
if device_type == "" then device_type = nil end
local macs_stats = interface.getMacsInfo(false, nil, 0, c_order,
					 source_macs_only, manufacturer, nil, device_type, "", nil)
local total_rows = #macs_stats["macs"]

local record = {}
local rsp = {}

if macs_stats.macs then
    for key, value in pairs(macs_stats["macs"]) do
        record = {}
        record["mac"] = value["mac"]

        local manufacturer = value["manufacturer"]
        if (manufacturer == nil) then
            manufacturer = ""
        end
        if (value["model"] ~= nil) then
            local _model = discover.apple_products[value["model"]] or value["model"]
            manufacturer = manufacturer .. " [ " .. shortenString(_model) .. " ]"
        end
        record["manufacturer"] = manufacturer
        
        local device_type_string = discover.devtype2stringId(value["devtype"])
        local device_type_label = discover.devtype2string(value["devtype"])
        local device_type = {
            device_type_label = device_type_label
        }
        if device_type_string == "printer" then device_type.printer = true end
        if device_type_string == "video" then device_type.video = true end 
        if device_type_string == "workstation" then device_type.workstation = true end
        if device_type_string == "laptop" then device_type.laptop = true end
        if device_type_string == "tablet" then device_type.tablet = true end
        if device_type_string == "phone" then device_type.phone = true end
        if device_type_string == "tv" then device_type.tv = true end
        if device_type_string == "networking" then device_type.networking = true end
        if device_type_string == "wifi" then device_type.wifi = true end
        if device_type_string == "nas" then device_type.nas = true end
        if device_type_string == "multimedia" then device_type.multimedia = true end
        if device_type_string == "iot" then device_type.iot = true end
        record["device_type"] = device_type

        local name_device = {name = getDeviceName(value["mac"], true), has_name = true}
        if (isEmptyString(name_device.name)) then
            name_device = macHosts(value.mac)
        end
        record["name"] = name_device
        
        record["hosts"] = value["num_hosts"]
        
        if (value["arp_requests.sent"] == None) then
            record["arp"] = 0
        else
            record["arp"] = formatValue(value["arp_requests.sent"] + value["arp_replies.sent"] +
                                                        value["arp_requests.rcvd"] + value["arp_replies.rcvd"])
        end
        
        record["seen_since"] = value["seen.first"]
        if ((value["bytes.sent"] == None) and (value.sent ~= None)) then
            value["bytes.sent"] = value.sent.bytes
            value["bytes.rcvd"] = value.rcvd.bytes
            value["throughput_bps"] = 0
        end

        record["breakdown"] = ""
        local total_bytes = value["bytes.sent"] + value["bytes.rcvd"]
        record["bytes_sent"] = value["bytes.sent"]
        record["bytes_rcvd"] = value["bytes.rcvd"]

        if (throughput_type == "pps") then
            record["throughput"] = value["throughput_pps"]
            record["throughput_type"] = "pps"
        else
            record["throughput"] = value["throughput_bps"]
            record["throughput_type"] = "bps"
        end
        record["traffic"] = value["bytes.sent"] + value["bytes.rcvd"]
        rsp[#rsp + 1] = record
    end
end
rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {["recordsTotal"] = total_rows})
