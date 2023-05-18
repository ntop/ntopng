--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local format_utils = require("format_utils")
local alert_consts = require "alert_consts"
local icmp_utils = require "icmp_utils"
local json = require "dkjson"
local http_utils = require("http_utils")

local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('application/json')

local ifid = _GET["ifid"]

if (ifid) and (not isEmptyString(ifid)) then
    interface.select(ifid)
else
    ifid = interface.getId()
end

local ifstats = interface.getStats()

-- System host parameters
local host = _GET["host"] -- TODO: merge
local flows_to_update = _GET["custom_hosts"]

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()
local flows_filter = getFlowsFilter()
local flows_stats
local total = 0

-- Add more details (debug only)
-- flows_filter["detailsLevel"] = "high"

if not flows_to_update then
    flows_stats = interface.getFlowsInfo(flows_filter["hostFilter"], flows_filter, flows_filter["talkingWith"],
        flows_filter["client"], flows_filter["server"], flows_filter["flow_info"])
    if (flows_stats == nil) then
        flows_stats = {}
    else
        total = flows_stats["numFlows"]
        flows_stats = flows_stats["flows"]
    end
else
    flows_stats = {}

    -- Only update the requested rows
    for _, k in pairs(split(flows_to_update, ",")) do
        local flow_key_and_hash = string.split(k, "@") or {}

        if (#flow_key_and_hash == 2) then
            local flow =
                interface.findFlowByKeyAndHashId(tonumber(flow_key_and_hash[1]), tonumber(flow_key_and_hash[2]))

            if ((flow ~= nil) and
                ((flows_filter.deviceIpFilter == nil) or (flows_filter.deviceIpFilter == flow["device_ip"])) and
                ((flows_filter.inIndexFilter == nil) or (flows_filter.inIndexFilter == flow["in_index"])) and
                ((flows_filter.outIndexFilter == nil) or (flows_filter.outIndexFilter == flow["out_index"]))) then
                flows_stats[#flows_stats + 1] = flow
            end
        end
    end
end

if (flows_stats == nil) then
    flows_stats = {}
end

for key, value in ipairs(flows_stats) do
    local flows_info = flows_stats[key]
    local info = ""
    -- use an italic font to indicate extra information added after sorting
    local italic = true

    if (not isEmptyString(flows_info["info"])) then
        info = flows_info["info"]
        italic = false
    elseif (not isEmptyString(flows_info["icmp"])) then
        flows_info["info"] = icmp_utils.get_icmp_type(value.icmp.type, true)

        if (value.icmp.entropy ~= nil) then
            local e = value.icmp.entropy
            local diff = e.max - e.min

            if (icmp_utils.is_suspicious_entropy(e.min, e.max)) then
                flows_info["info"] = flows_info["info"] .. " <span class=\"badge bg-warning\">" ..
                                         i18n("suspicious_payload") .. "</span>"
            end
        end
    elseif (flows_info["proto.ndpi"] == "SIP") then
        info = getSIPInfo(flows_info)
    elseif (starts(flows_info["proto.ndpi"], "RTP")) then
        flows_info["info"] = getRTPInfo(flows_info)
    end

    if (flows_info["info"] == nil) then
        if (starts(info, "<i class")) then
            flows_info["info"] = info
        else
            -- safety checks against injections
            info = noHtml(info)
            info = info:gsub('"', '')
            local alt_info = info

            if italic then
                info = string.format("<i>%s</i>", info)
            end
            info = shortenString(info)

            -- Add extra icons to info column
            if (flows_info["protos.dns.last_query_type"] or flows_info["protos.dns.last_return_code"]) then
                local dns_info = format_dns_query_info({
                    last_query_type = flows_info["protos.dns.last_query_type"],
                    last_return_code = flows_info["protos.dns.last_return_code"]
                })

                if (dns_info.last_query_type ~= 0) then
                    info = dns_info.last_query_type .. " " .. dns_info.last_return_code .. " " .. info
                else
                    info = dns_info.last_query_type .. info
                end
            end

            if flows_info["protos.http.last_return_code"] or flows_info["protos.http.last_method"] then
                local http_info = format_http_info({
                    last_return_code = flows_info["protos.http.last_return_code"],
                    last_method = flows_info["protos.http.last_method"]
                })
                info = (http_info.last_return_code or '') .. " " .. http_info.last_method .. " " .. info
            end

            flows_info["info"] = "<span data-bs-toggle='tooltip' title='" .. alt_info .. "'>" .. info .. "</span>"
        end
    end

    if (flows_info["profile"] ~= nil) then
        flows_info["info"] = formatTrafficProfile(flows_info["profile"]) .. flows_info["info"]
    end

    -- tprint(flows_info["info"])
end

local formatted_res = {}
for _key, value in ipairs(flows_stats) do -- pairsByValues(vals, funct) do
    local record = {}
    local key = value["ntopng.key"]
    local info_cli = interface.getHostMinInfo(value["cli.ip"], value["cli.vlan"])
    local info_srv = interface.getHostMinInfo(value["srv.ip"], value["srv.vlan"])

    if not info_cli then
        info_cli = {
            host = value["cli.ip"],
            vlan = value["cli.vlan"]
        }
    end

    if not info_srv then
        info_srv = {
            host = value["srv.ip"],
            vlan = value["srv.vlan"]
        }
    end

    -- Print labels.
    local cli_name = hostinfo2label(info_cli, true, 36)
    local srv_name = hostinfo2label(info_srv, true, 36)

    local src_port, dst_port = '', ''
    local src_process, dst_process = '', ''
    local src_container, dst_container = '', ''

    local cli_tooltip = hostinfo2label({
        label = info_cli.host or info_cli.ip,
        vlan = info_cli.vlan or 0
    }, true)
    local srv_tooltip = hostinfo2label({
        label = info_srv.host or info_srv.ip,
        vlan = info_srv.vlan or 0
    }, true)

    if ((value["tcp.nw_latency.client"] ~= nil) and (value["tcp.nw_latency.client"] > 0)) then
        cli_tooltip = cli_tooltip .. "&#10;nw latency: " .. string.format("%.3f", value["tcp.nw_latency.client"]) ..
                          " ms"
    end

    if ((value["tcp.nw_latency.server"] ~= nil) and (value["tcp.nw_latency.server"] > 0)) then
        srv_tooltip = srv_tooltip .. "&#10;nw latency: " .. string.format("%.3f", value["tcp.nw_latency.server"]) ..
                          " ms"
    end

    if value["cli.allowed_host"] and not ifstats.isViewed then
        local src_name = shortenString(cli_name, 36)

        if (value["cli.systemhost"] == true) then
            src_name = src_name .. "&nbsp;<i class='fas fa-flag'></i>"
        end
        src_key = hostinfo2detailshref(flow2hostinfo(value, "cli"), nil, src_name, cli_tooltip, false)

        if value["cli.port"] > 0 or value["proto.l4"] == "TCP" or value["proto.l4"] == "UDP" then
            src_port = "<A HREF='" .. ntop.getHttpPrefix() .. "/lua/flows_stats.lua?port=" .. value["cli.port"]
            if (host ~= nil) then
                src_port = src_port .. "&host=" .. host
            end
            src_port = src_port .. "'>" .. ntop.getservbyport(value["cli.port"], string.lower(value["proto.l4"])) ..
                           "</A>"
        end

        -- record["column_client_process"] = flowinfo2process(value["client_process"], hostinfo2url(value,"cli"))
        src_process = flowinfo2process(value["client_process"], hostinfo2url(value, "cli"))
        src_container = flowinfo2container(value["client_container"])
    else
        src_key = shortenString(cli_name, 36)

        if value["cli.port"] > 0 then
            src_port = value["cli.port"] .. ''
        end
    end

    if value["srv.allowed_host"] and not ifstats.isViewed then
        local dst_name = shortenString(srv_name, 36)
        if (value["srv.systemhost"] == true) then
            dst_name = dst_name .. "&nbsp;<i class='fas fa-flag'></i>"
        end
        dst_key = hostinfo2detailshref(flow2hostinfo(value, "srv"), nil, dst_name, srv_tooltip, false)

        if value["srv.port"] > 0 or value["proto.l4"] == "TCP" or value["proto.l4"] == "UDP" then
            dst_port = "<A HREF='" .. ntop.getHttpPrefix() .. "/lua/flows_stats.lua?port=" .. value["srv.port"]
            if (host ~= nil) then
                dst_port = dst_port .. "&host=" .. host
            end
            dst_port = dst_port .. "'>" .. ntop.getservbyport(value["srv.port"], string.lower(value["proto.l4"])) ..
                           "</A>"
        else
            dst_port = ""
        end

        -- record["column_server_process"] = flowinfo2process(value["server_process"], hostinfo2url(value,"srv"))
        dst_process = flowinfo2process(value["server_process"], hostinfo2url(value, "srv"))
        dst_container = flowinfo2container(value["server_container"])

        if value["server_container"] and value["server_container"].id then
            record["column_server_container"] =
                '<a href="' .. ntop.getHttpPrefix() .. '/lua/flows_stats.lua?container=' .. value["server_container"].id ..
                    '">' .. format_utils.formatContainer(value["server_container"]) .. '</a>'

            if value["server_container"]["k8s.pod"] then
                record["column_server_pod"] = '<a href="' .. ntop.getHttpPrefix() .. '/lua/containers_stats.lua?pod=' ..
                                                  value["server_container"]["k8s.pod"] .. '">' ..
                                                  shortenString(value["server_container"]["k8s.pod"]) .. '</a>'
            end
        end
    else
        dst_key = shortenString(srv_name, 36)

        if value["srv.port"] > 0 then
            dst_port = value["srv.port"] .. ""
        end
    end

    record["column_first_seen"] = formatEpoch(value["seen.first"])
    record["column_last_seen"] = formatEpoch(value["seen.last"])

    if (value["client_tcp_info"] ~= nil) then
        record["column_client_rtt"] = format_utils.formatMillis(value["client_tcp_info"]["rtt"])
    end
    if (value["server_tcp_info"] ~= nil) then
        record["column_server_rtt"] = format_utils.formatMillis(value["server_tcp_info"]["rtt"])
    end

    local column_key = "<A class='btn btn-sm btn-info' HREF='" .. ntop.getHttpPrefix() ..
                           "/lua/flow_details.lua?flow_key=" .. value["ntopng.key"] .. "&flow_hash_id=" ..
                           value["hash_entry_id"] .. "'><i class='fas fa-search-plus'></i></A>"
    if (have_nedge) then
        if (value["verdict.pass"]) then
            column_key = column_key .. " <span id='" .. value["ntopng.key"] .. "_" .. value["hash_entry_id"] ..
                             "_block' " .. "title='" .. i18n("flow_details.drop_flow_traffic_btn") ..
                             "' class='btn btn-sm btn-secondary block-badge' " ..
                             (ternary(isAdministrator(),
                    "onclick='block_flow(" .. value["ntopng.key"] .. ", " .. value["hash_entry_id"] ..
                        ");' style='cursor: pointer;'", "")) .. "><i class='fas fa-ban' /></span>"
        else
            column_key = column_key .. " <span title='" .. i18n("flow_details.flow_traffic_is_dropped") ..
                             "' class='btn btn-sm btn-danger block-badge'><i class='fas fa-ban' /></span>"
        end
    end

    record["column_key"] = column_key
    record["key"] = string.format("%u", value["ntopng.key"])
    record["hash_id"] = string.format("%u", value["hash_entry_id"])
    record["key_and_hash"] = string.format("%s@%s", record["key"], record["hash_id"])

    if (value["in_index"] ~= nil and value["out_index"] ~= nil) then
        local device_ip = value["device_ip"]

        local idx_name_in = i18n("span_with_title", {
            shorten_name = format_portidx_name(device_ip, value["in_index"], true, true),
            url = ntop.getHttpPrefix() .. '/lua/pro/enterprise/flowdevice_details.lua?ip=' .. value["device_ip"] ..
                '&snmp_port_idx=' .. value["in_index"]
        })

        local idx_name_out = i18n("span_with_title", {
            shorten_name = format_portidx_name(device_ip, value["out_index"], true, true),
            url = ntop.getHttpPrefix() .. '/lua/pro/enterprise/flowdevice_details.lua?ip=' .. value["device_ip"] ..
                '&snmp_port_idx=' .. value["out_index"]
        })

        record["column_device_ip"] = i18n("span_with_title", {
            shorten_name = getProbeName(value["device_ip"]),
            url = ntop.getHttpPrefix() .. '/lua/pro/enterprise/flowdevice_details.lua?ip=' .. value["device_ip"]
        })

        record["column_in_index"] = idx_name_in
        record["column_out_index"] = idx_name_out
    end

    local column_client = src_key

    if info_cli then
        column_client = column_client .. format_utils.formatMainAddressCategory(info_cli)
    end

    column_client = string.format("%s%s%s %s %s", column_client, ternary(src_port ~= '', ':', ''), src_port,
        src_process, src_container)

    if (value["verdict.pass"] == false) then
        column_client = "<strike>" .. column_client .. "</strike>"
    end

    record["column_client"] = column_client

    local column_server = dst_key

    if info_srv then
        column_server = column_server .. format_utils.formatMainAddressCategory(info_srv)
    end

    column_server = string.format("%s%s%s %s %s", column_server, ternary(dst_port ~= '', ':', ''), dst_port,
        dst_process, dst_container)
    if (value["verdict.pass"] == false) then
        column_server = "<strike>" .. column_server .. "</strike>"
    end
    record["column_server"] = column_server

    local column_proto_l4 = ''

    if value["predominant_alert"] then
        column_proto_l4 = alert_consts.alertTypeIcon(value["predominant_alert"],
            map_score_to_severity(value["predominant_alert_score"]))
    end

    if tonumber(value["proto.l4"]) then
        value["proto.l4"] = l4_proto_to_string(value["proto.l4"])
    end

    column_proto_l4 = value["proto.l4"] .. " " .. column_proto_l4

    if (value["verdict.pass"] == false) then
        column_proto_l4 = "<strike>" .. column_proto_l4 .. "</strike>"
    end
    record["column_proto_l4"] = column_proto_l4

    local app = getApplicationLabel(value["proto.ndpi"])

    if (value["verdict.pass"] == false) then
        app = "<strike>" .. app .. "</strike>"
    end

    record["column_ndpi"] = app -- can't set the hosts_stats hyperlink for viewed interfaces
    if (value["proto.ndpi_id"] ~= -1) then
        local l7proto

        if ((value["proto.ndpi_id"] == value["proto.master_ndpi_id"]) or (value["proto.master_ndpi_id"] == 0)) then
            l7proto = value["proto.ndpi_id"]
        else
            l7proto = value["proto.master_ndpi_id"] .. "." .. value["proto.ndpi_id"]
        end

        record["column_ndpi"] = "<A HREF='" .. ntop.getHttpPrefix() .. "/lua/flows_stats.lua?application=" .. l7proto ..
                                    "'&ifid='" .. ifid .. "'>" .. app .. " " ..
                                    formatBreed(value["proto.ndpi_breed"], value["proto.is_encrypted"]) .. "</A>"
        record["column_ndpi"] = record["column_ndpi"] .. " " .. format_confidence_badge(ternary(value["proto.ndpi_id"] == 0, -1, value["confidence"]))
        --      record["column_ndpi"] = record["column_ndpi"] .. " " .. "<a href='".. ntop.getHttpPrefix().."/lua/hosts_stats.lua?protocol=" .. value["proto.ndpi_informative_proto"] .. "' title='" .. i18n("host_details.hosts_using_proto", { proto = interface.getnDPIProtoName(value["proto.ndpi_informative_proto"]) }) .. "'><i class='fa-solid fa-timeline'></i></a>"
    end
    record["column_duration"] = secondsToTime(value["duration"])
    record["column_bytes"] = value["bytes"]

    local column_thpt = ''
    if (throughput_type == "pps") then
        column_thpt = value["throughput_pps"]
    else
        column_thpt = 8 * value["throughput_bps"]
    end

    if false then
        if ((value["throughput_trend_" .. throughput_type] ~= nil) and
            (value["throughput_trend_" .. throughput_type] > 0)) then
            if (value["throughput_trend_" .. throughput_type] == 1) then
                column_thpt = column_thpt .. "<i class='fas fa-arrow-up'></i>"
            elseif (value["throughput_trend_" .. throughput_type] == 2) then
                column_thpt = column_thpt .. "<i class='fas fa-arrow-down'></i>"
            elseif (value["throughput_trend_" .. throughput_type] == 3) then
                column_thpt = column_thpt .. "<i class='fas fa-minus'></i>"
            end
        end
    end

    record["column_thpt"] = column_thpt

    local cli2srv = round((value["cli2srv.bytes"] * 100) / value["bytes"], 0)

    record["column_breakdown"] =
        "<div class='progress'><div class='progress-bar bg-warning' style='width: " .. cli2srv ..
            "%;'>Client</div><div class='progress-bar bg-success' style='width: " .. (100 - cli2srv) ..
            "%;'>Server</div></div>"

    local info = shortenString(value["info"], 32)

    if isScoreEnabled() then
        record["column_score"] = format_utils.formatValue(value.score.flow_score)
    end

    if (value.periodic_flow) then
        info = info .. " <A HREF='" .. ntop.getHttpPrefix() ..
                   "/lua/pro/enterprise/network_maps.lua?map=periodicity_map&page=table"

        if ((info_cli ~= nil) and (info_cli.ip ~= nil)) then
            local k

            if (value["cli.serialize_by_mac"] and (value["cli.mac"] ~= nil)) then
                k = value["cli.mac"]
            else
                k = value["cli.ip"]
            end

            info = info .. "&host=" .. k .. "&l7proto=" .. value["proto.ndpi"]
        end

        info = info .. "'><span class='badge bg-warning text-dark'>" .. i18n("periodic_flow") .. "</span></h1></A>"
    end

    if (not isEmptyString(value["protos.http.last_method"])) then
        local span_mode
        local color
        local rcode

        if (value["protos.http.last_method"] == "GET") then
            span_mode = "success"
        else
            span_mode = "warning"
        end

        if (value["protos.http.last_return_code"] < 400) then
            color = "badge bg-success"
        else
            color = "badge bg-danger"
        end

        rcode = http_utils.getResponseStatusCode(value["protos.http.last_return_code"]) or ''
        info = "<span class='badge bg-" .. span_mode .. "'>" .. value["protos.http.last_method"] ..
                   "</span> <span class='" .. color .. "'>" .. rcode .. "</span> " .. info
    end

    record["column_info"] = info

    formatted_res[#formatted_res + 1] = record

end -- for

local result = {
    perPage = flows_filter["perPage"],
    currentPage = flows_filter["currentPage"],
    totalRows = total,
    data = formatted_res,
    sort = {{flows_filter["sortColumn"], flows_filter["sortOrder"]}}
}

print(json.encode(result))
