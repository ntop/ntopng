--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "label_utils"
require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"
local vs_utils = require "vs_utils"

-- Table parameters
local all = _GET["all"]
local length = tonumber(_GET["length"])
local start = tonumber(_GET["start"])
local sort_column = _GET["sort"]
local sort_order = _GET["order"]
local protocol = _GET["protocol"]
local custom_column = _GET["custom_column"]
local traffic_type = _GET["traffic_type"]
local device_ip = _GET["deviceIP"]

-- Host comparison parameters
local mode = _GET["mode"]
local tracked = _GET["tracked"]
local ipversion = _GET["version"]

-- Used when filtering by ASn, VLAN or network
local asn = _GET["asn"]
local vlan = _GET["vlan"]
local network = _GET["network"]
local cidr = _GET["network_cidr"]
local pool = _GET["pool"]
local country = _GET["country"]
local os_ = tonumber(_GET["os"])
local mac = _GET["mac"]

local c_order = true
local lua_order = asc
local filtered_hosts = false
local blacklisted_hosts = false
local anomalous = false
local dhcp_hosts = false
local throughput_type = getThroughputType()

if (sort_order == "desc") then
    lua_order = rev
    c_order = false
end

local hosts_retrv_function = interface.getHostsInfo

if mode == "local" then
    hosts_retrv_function = interface.getLocalHostsInfo
elseif mode == "local_no_tx" then
    hosts_retrv_function = interface.getLocalHostsInfoNoTX
elseif mode == "local_no_tcp_tx" then
    hosts_retrv_function = interface.getLocalHostsInfoNoTXTCP
elseif mode == "remote" then
    hosts_retrv_function = interface.getRemoteHostsInfo
elseif mode == "remote_no_tx" then
    hosts_retrv_function = interface.getRemoteHostsInfoNoTX
elseif mode == "remote_no_tcp_tx" then
    hosts_retrv_function = interface.getRemoteHostsInfoNoTXTCP
elseif mode == "broadcast_domain" then
    hosts_retrv_function = interface.getBroadcastDomainHostsInfo
elseif mode == "broadcast_multicast" then
    hosts_retrv_function = interface.getBroadcastMulticastHostsInfo
elseif mode == "filtered" then
    filtered_hosts = true
elseif mode == "blacklisted" then
    blacklisted_hosts = true
elseif mode == "dhcp" then
    dhcp_hosts = true
end
local traffic_type_filter

if traffic_type == "one_way" then
    traffic_type_filter = 1 -- ntop_typedefs.h TrafficType traffic_type_one_way
elseif traffic_type == "bidirectional" then
    traffic_type_filter = 2 -- ntop_typedefs.h TrafficType traffic_type_bidirectional
end

if isEmptyString(device_ip) then
    device_ip = nil
end

local filtered_hosts = false
local blacklisted = false
local anomalous = false
local dhcp_hosts = false
local rsp = {}

local mapping_column_lua_c = {
    ip_address = "column_ip",
    alerts = "column_alerts",
    hostname = "column_name",
    num_flows = "column_num_flows",
    score = "column_score",
    first_seen = "column_since",
    throughput = "column_thpt",
    bytes = "column_traffic",
    vlan = "column_vlan"
}

local hosts_stats = hosts_retrv_function(false, mapping_column_lua_c[sort_column], length, start, c_order, country, os_, tonumber(vlan),
    tonumber(asn), tonumber(network), mac, tonumber(pool), tonumber(ipversion), tonumber(protocol), traffic_type_filter,
    filtered_hosts, blacklisted_hosts, anomalous, dhcp_hosts, cidr, device_ip, true --[[ Array format ]])

for key, value in pairs(hosts_stats["hosts"]) do
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
    if value["devtype"] then
        column_ip.device_type = value["devtype"]
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
    if value["is_multicast"] then
        column_ip.is_multicast = true
    elseif value["localhost"] then
        column_ip.localhost = true
    else
        column_ip.remotehost = true
    end
    if value["is_blackhole"] then
        column_ip.is_blackhole = value["is_blackhole"]
    end

    record.hostname = {
        alt_name = "",
        name = value["name"]
    }

    if value["has_blocking_quota"] or value["has_blocking_shaper"] then
        column_ip.blocking_traffic_policy = true
    end
    local alt_name = getHostAltName(value["ip"])
    if not isEmptyString(alt_name) then
        record.hostname.alt_name = alt_name
    end

    column_ip["mac"] = {
        address = value["mac"],
        name = getDeviceName(value["mac"])
    }

    column_ip["vlan"] = {
        name = '',
        id = 0
    }

    if not isEmptyString(value["vlan"]) then
        column_ip["vlan"]["name"] = getFullVlanName(value["vlan"])
        column_ip["vlan"]["id"] = value["vlan"]
    end

    local host_vulnerabilities = vs_utils.retrieve_host(value["ip"])

    if (host_vulnerabilities) and not isEmptyString(host_vulnerabilities.num_vulnerabilities_found) then
        record["num_cves"] = host_vulnerabilities.num_vulnerabilities_found
    end

    record["host"] = column_ip
    record["first_seen"] = value["seen.first"]
    record["last_seen"] = value["seen.last"]

    record.throughput = {
        type = throughput_type,
        pps = value["throughput_pps"],
        bps = value["throughput_bps"],
        trend = value["throughput_trend_"..throughput_type]
    }
    record["bytes"] = {
        total = value["bytes.sent"] + value["bytes.rcvd"],
        sent = value["bytes.sent"],
        rcvd = value["bytes.rcvd"]
    }
    record["alerts"] = value["num_alerts"]
    record["num_flows"] = value["active_flows.as_client"] + value["active_flows.as_server"]
    record["score"] = value["score"]
    rsp[#rsp + 1] = record
end

rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
    ["recordsTotal"] = hosts_stats["numHosts"]
})
