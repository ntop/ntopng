--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local http_utils = require "http_utils"
local rest_utils = require "rest_utils"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local l4_protocol_list = require "l4_protocol_list"

-- Trick to handle the application and the categories togheter
local application = _GET["application"]
local ip_version_or_host = _GET["flowhosts_type"]

if not isEmptyString(application) then
    if string.starts(application, "cat_") then
        local category = split(application, "cat_")
        _GET["category"] = category[2]
        _GET["application"] = nil
    end
end

if not isEmptyString(ip_version_or_host) then
    if string.starts(ip_version_or_host, "ip_version_") then
        local version = split(ip_version_or_host, "ip_version_")
        _GET["version"] = version[2]
        _GET["flowhosts_type"] = nil
    else
        local host = hostkey2hostinfo(p)
        if host then
            _GET["host"] = ip_version_or_host
            _GET["flowhosts_type"] = nil
        end
    end
end

local throughput_type = getThroughputType()
local ifid = interface.getId()
local flows_filter = getFlowsFilter()

local mapping_column_lua_c = {
    server = "column_server",
    client = "column_client",
    l4_proto = "column_proto_l4",
    application = "column_ndpi",
    protocol = "column_protocol",
    score = "column_score",
    first_seen = "column_first_seen",
    last_seen = "column_last_seen",
    throughput = "column_thpt",
    bytes = "column_bytes",
    info = "column_info",
    flow_exporter = "column_device_ip",
    in_index = "column_in_index",
    out_index = "column_out_index"
}

if _GET["start"] and _GET["length"] then
    flows_filter.perPage = tonumber(_GET["length"])
    flows_filter.maxHits = tonumber(_GET["length"])
    flows_filter.toSkip = tonumber(_GET["start"])
end

if not isEmptyString(_GET["sort"]) then
    flows_filter.sortColumn = mapping_column_lua_c[_GET["sort"]]
    local order = _GET["order"]
    if order == "asc" then
        flows_filter.a2zSortOrder = true
    else
        flows_filter.a2zSortOrder = false
    end
end

-- A cheat for retrocompatibility
if not isEmptyString(flows_filter.statusFilter) then
    local alert_severity_groups = require "alert_severity_groups"
    for alert_severity, value in pairs(alert_severity_groups) do
        if (alert_severity == flows_filter.statusFilter) then
            flows_filter.statusSeverityFilter = value.severity_group_id
            flows_filter.statusFilter = nil
            break
        end
    end
end

local rsp = {}
local flows_stats = interface.getFlowsInfo(flows_filter["hostFilter"], flows_filter, flows_filter["talkingWith"],
    flows_filter["client"], flows_filter["server"], flows_filter["flow_info"])

if not flows_stats then
    rest_utils.extended_answer(rest_utils.consts.success.ok, {}, {
        ["recordsTotal"] = 0
    })
    return
end

for _, value in ipairs(flows_stats.flows) do
    local record = {}
    local key = value["ntopng.key"]
    local info_cli = interface.getHostMinInfo(value["cli.ip"], value["cli.vlan"])
    local info_srv = interface.getHostMinInfo(value["srv.ip"], value["srv.vlan"])

    if not info_cli then
        info_cli = {
            host = value["cli.ip"],
            vlan = value["cli.vlan"],
            localhost = value["cli.localhost"],
            systemhost = value["cli.systemhost"]
        }
    end

    if not info_srv then
        info_srv = {
            host = value["srv.ip"],
            vlan = value["srv.vlan"],
            localhost = value["srv.localhost"],
            systemhost = value["srv.systemhost"]
        }
    end

    -- Formatting client column
    local client = {
        ip = value["cli.ip"],
        vlan = value["cli.vlan"],
        name = hostinfo2label(info_cli, true),
        port = value["cli.port"],
        process = {},
        container = {}
    }
    client = format_utils.formatMainAddressCategoryNoHTML(info_cli, client)
    client.allowed_host = value["cli.allowed_host"] and not interface.isViewed()
    if client.allowed_host then
        if value["cli.port"] > 0 or value["proto.l4"] == "TCP" or value["proto.l4"] == "UDP" then
            client.service_port = ntop.getservbyport(value["cli.port"], string.lower(value["proto.l4"]))
        end
    end

    if (value["cli.serialize_by_mac"] and (value["cli.mac"] ~= nil)) then
        client.mac = value["cli.mac"]
    end
    if value["client_process"] and not isEmptyString(value["client_process"]["name"]) then
        local name = value["client_process"]["name"]
        client.process.name = name
        client.process.pid = value["client_process"]["pid"]
        client.process.pid_name = value["client_process"]["name"]:gsub("'", '')
        local tmp = split(client.process.pid_name, "/")
        client.process.process_name = tmp[#tmp]
    end
    if value["client_container"] then
        client.container.id = value["client_container"]["id"]
        client.container.name = format_utils.formatContainer(value["client_container"])
    end

    -- Formatting server column
    local server = {
        ip = value["srv.ip"],
        vlan = value["srv.vlan"],
        name = hostinfo2label(info_srv, true),
        port = value["srv.port"],
        process = {},
        container = {}
    }
    server = format_utils.formatMainAddressCategoryNoHTML(info_srv, server)
    server.allowed_host = value["srv.allowed_host"] and not interface.isViewed()
    if server.allowed_host then
        if value["cli.port"] > 0 or value["proto.l4"] == "TCP" or value["proto.l4"] == "UDP" then
            server.service_port = ntop.getservbyport(value["srv.port"], string.lower(value["proto.l4"]))
        end
    end

    if value["server_process"] and not isEmptyString(value["server_process"]["name"]) then
        local name = value["server_process"]["name"]
        server.process.name = name
        server.process.pid = value["server_process"]["pid"]
        server.process.pid_name = value["server_process"]["name"]:gsub("'", '')
        local tmp = split(server.process.pid_name, "/")
        server.process.process_name = tmp[#tmp]
    end
    if value["server_container"] then
        server.container.id = value["server_container"]["id"]
        server.container.name = format_utils.formatContainer(value["server_container"])
        server.container.pod = value["server_container"]["k8s.pod"]
    end

    if (value["in_index"] ~= nil and value["out_index"] ~= nil) then
        local device_ip = value["device_ip"]

        record.flow_exporter = {
            device = {
                ip = value["device_ip"],
                name = getProbeName(value["device_ip"])
            },
            in_port = {
                index = value["in_index"],
                name = format_portidx_name(device_ip, value["in_index"])
            },
            out_port = {
                index = value["out_index"],
                name = format_portidx_name(device_ip, value["out_index"])
            }
        }

        if interface.isView() then
            record.flow_exporter.seen_on_interface = {
                name = getInterfaceName(value["iface_index"], true),
                id = value["iface_index"]
            }
        end
    end

    if value["predominant_alert"] then
        record["predominant_alert"] = {
            severity_id = map_score_to_severity(value["predominant_alert_score"]),
            name = alert_consts.alertTypeLabel(value["predominant_alert"], true)
        }
    end

    local proto_id = 0
    for _, proto in pairs(l4_protocol_list.l4_keys) do
        if proto[1] == value["proto.l4"] or proto[2] == value["proto.l4"] then
            proto_id = (proto[3])
            break
        end
    end
    record["l4_proto"] = {
        id = proto_id,
        name = value["proto.l4"]
    }
    record["first_seen"] = value["seen.first"]
    record["last_seen"] = value["seen.last"]
    record["key"] = string.format("%u", value["ntopng.key"])
    record["hash_id"] = string.format("%u", value["hash_entry_id"])
    record["verdict"] = not (value["verdict.pass"] ~= nil and value["verdict.pass"] == false)
    record["duration"] = value["duration"]
    record["info"] = value["info"]
    record["periodic_flow"] = value.periodic_flow
    record["client"] = client
    record["server"] = server
    record["ifid"] = ifid
    if value.score then
        record["score"] = value.score.flow_score
    end
    record["bytes"] = {
        total = value["bytes"],
        cli_bytes = value["cli2srv.bytes"],
        srv_bytes = value["srv2cli.bytes"]
    }
    record["throughput"] = {
        type = throughput_type,
        pps = value["throughput_pps"],
        bps = 8 * (value["throughput_bps"] or 0),
        trend = value["throughput_trend_" .. throughput_type]
    }
    record["application"] = {
        confidence_id = value["confidence"],
        confidence = get_confidence(value["confidence"]),
        name = value["proto.ndpi"],
        master_id = value["proto.master_ndpi_id"],
        app_id = value["proto.ndpi_id"],
        breed = value["proto.ndpi_breed"],
        encrypted = value["proto.is_encrypted"]
    }

    if (not isEmptyString(value["protos.http.last_method"])) then
        record["application"]["http_method"] = value["protos.http.last_method"]
        record["application"]["return_code"] = value["protos.http.last_return_code"]
        record["application"]["rsp_status_code"] = http_utils.getResponseStatusCode(
            value["protos.http.last_return_code"])
    end

    rsp[#rsp + 1] = record
end

rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
    ["recordsTotal"] = flows_stats["numFlows"]
})
