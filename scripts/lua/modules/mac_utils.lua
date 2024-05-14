--
-- (C) 2014-24 - ntop.org
--
require "ntop_utils"
require "check_redis_prefs"
local discover = require "discover_utils"

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

local now = os.time()

-- ##############################################

-- Mac Addresses --

local specialMACs = {"01:00:0C", "01:80:C2", "01:00:5E", "01:0C:CD", "01:1B:19", "FF:FF", "33:33"}

-- ##############################################

local function isSpecialMac(mac)
    for _, key in pairs(specialMACs) do
        if (string.contains(mac, key)) then
            return true
        end
    end

    return false
end

-- ################################################

function printMacHosts(mac)
    require "lua_utils_gui"
    local mac_hosts = interface.getMacHosts(mac)
    local num_hosts = table.len(mac_hosts)

    if num_hosts > 0 then
        local first_host

        for _, h in pairsByKeys(mac_hosts, asc) do
            first_host = h
            break
        end

        local url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?mac=" .. mac
        local host_url = hostinfo2detailsurl(first_host)
        local host_label = first_host["ip"]

        if num_hosts > 2 then
            return i18n("mac_details.and_n_more_hosts", {
                host_url = host_url,
                host_label = host_label,
                url = url,
                num = num_hosts
            })
        elseif num_hosts > 1 then
            return i18n("mac_details.and_one_more_host", {
                host_url = host_url,
                host_label = host_label,
                url = url
            })
        else
            return i18n("mac_details.mac_host", {
                host_url = host_url,
                host_label = host_label
            })
        end
    end

    return ''
end

-- ################################################

function getMacHosts(mac, additional_ip)
    local mac_hosts = interface.getMacHosts(mac)
    local num_hosts = table.len(mac_hosts)
    local url, hosts

    if (additional_ip ~= nil) then
        mac_hosts[additional_ip] = {}
        mac_hosts[additional_ip]["ip"] = additional_ip
    end

    if (num_hosts > 0) then
        local first_host

        for _, h in pairsByKeys(mac_hosts, asc) do
            first_host = h
            break
        end

        url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?mac=" .. mac

        if num_hosts == 1 then
            hosts = first_host["ip"]
        elseif num_hosts > 1 then
            hosts = i18n("n_more_objects", {
                label = first_host["ip"],
                num = num_hosts,
                object = i18n("hosts")
            })
        end
    end

    return hosts, url
end

-- ################################################

function macAddIcon(mac, pre)
    local pre = pre or mac
    if not isSpecialMac(mac) then
        local icon = discover.devtype2icon(mac.devtype)

        if not isEmptyString(icon) then
            return pre .. "&nbsp;" .. icon
        end
    end

    return pre
end

-- ################################################

function mac2url(mac)
    return ntop.getHttpPrefix() .. '/lua/mac_details.lua?' .. hostinfo2url(mac)
end

-- ################################################

function mac2link(mac, cached_name, alt_name)
    local macaddress = mac["mac"]

    if alt_name and not isEmptyString(alt_name) then
        macaddress = alt_name
    end

    if cached_name then
        macaddress = mac2label(macaddress)
    end

    return "<A HREF='" .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?' .. hostinfo2url(mac) .. "' title='" ..
               macaddress .. "'>" .. macaddress .. '</A>'
end

-- ################################################

function mac2record(mac)
    local record = {}
    record["key"] = hostinfo2jqueryid(mac)

    if (mac["bytes.sent"] == None) then
        record["column_mac"] = mac.mac
    else
        record["column_mac"] = mac2link(mac)
    end

    if (mac.fingerprint ~= "") then
        record["column_mac"] = record["column_mac"] ..
                                   ' <i class="fas fa-hand-o-up fa-lg" aria-hidden="true" title="DHCP Fingerprinted"></i>'
        -- io.write(mac.fingerprint.."\n")
    end

    local manufacturer = get_manufacturer_mac(mac["mac"])
    if (manufacturer == nil) then
        manufacturer = ""
    end

    if (mac["model"] ~= nil) then
        local _model = discover.apple_products[mac["model"]] or mac["model"]
        manufacturer = manufacturer .. " [ " .. shortenString(_model) .. " ]"
    end

    record["column_manufacturer"] = manufacturer

    if (mac["arp_requests.sent"] == None) then
        record["column_arp_total"] = 0
    else
        record["column_arp_total"] = formatValue(mac["arp_requests.sent"] + mac["arp_replies.sent"] +
                                                     mac["arp_requests.rcvd"] + mac["arp_replies.rcvd"])
    end

    record["column_device_type"] = discover.devtype2string(mac["devtype"]) .. " " ..
                                       discover.devtype2icon(mac["devtype"])
    record["column_hosts"] = format_high_num_value_for_tables(mac, "num_hosts")

    if (mac["seen.first"] ~= None) then
        record["column_since"] = secondsToTime(now - mac["seen.first"] + 1)
    else
        record["column_since"] = secondsToTime(now - mac.seen.first + 1)
    end

    if ((mac["bytes.sent"] == None) and (mac.sent ~= None)) then
        mac["bytes.sent"] = mac.sent.bytes
        mac["bytes.rcvd"] = mac.rcvd.bytes
        mac["throughput_bps"] = 0
    end

    local sent2rcvd = round((mac["bytes.sent"] * 100) / (mac["bytes.sent"] + mac["bytes.rcvd"]), 0)
    record["column_breakdown"] = "<div class='progress'><div class='progress-bar bg-warning' style='width: " ..
                                     sent2rcvd .. "%;'>Sent</div><div class='progress-bar bg-success' style='width: " ..
                                     (100 - sent2rcvd) .. "%;'>Rcvd</div></div>"

    if (throughput_type == "pps") then
        record["column_thpt"] = pktsToSize(mac["throughput_pps"])
    else
        record["column_thpt"] = bitsToSize(8 * mac["throughput_bps"])
    end

    record["column_traffic"] = bytesToSize(mac["bytes.sent"] + mac["bytes.rcvd"])

    local name = getDeviceName(mac["mac"], true)

    if (isEmptyString(name)) then
        name = printMacHosts(mac.mac)
    end
    record["column_name"] = name

    return record
end

