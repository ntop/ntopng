--
-- (C) 2013-25 - ntop.org
--
--
-- Logic implemented.
-- Example for a given router 1.2.3.4 the flows below are rcvd
-- (a) [ASN] src=34978 -> dst=12337 | [Port Idx] in=146 -> out=132 | sent=60 / rcvd=0
-- (b) [ASN] src=34978 -> dst=12337 | [Port Idx] in=146 -> out=136 | sent=0  / rcvd=594
--
-- Flow a
-- Port 146  = { rcvd = 60,  sent = 0 }, port 132 = { rcvd = 0, sent = 60 }, port 136 = { rcvd = 0, sent = 0 }
-- ASN 34978 = { rcvd = 0,  sent = 60 }
-- ASN 12337 = { rcvd = 60, sent = 0  }
--
-- Flow a+b
-- Port 146  = { rcvd  = 60,  sent = 594 }, port 132 = { rcvd = 0, sent = 60 }, port 136 = { rcvd = 594, sent = 0  }
-- ASN 34978 = { rcvd = 594, sent = 60   }
-- ASN 12337 = { rcvd = 60,  sent = 594  }
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
require "label_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local format_utils = require "format_utils"
local info = ntop.getInfo()
local callback_utils = require "callback_utils"

local rc = rest_utils.consts.success.ok
local ifid = _GET["ifid"]
local criteria_as = _GET["criteria_as"]
local asn = tonumber(_GET["asn"])
local rsp = {}

local edges = {}
local nodes = {}

local traffic_criteria = {INGRESS = 0, EGRESS = 1, TOTAL = 2, ING_EGR = 3}

local criteria

if criteria_as == "egress_traffic_criteria" then
    criteria = traffic_criteria.EGRESS
elseif criteria_as == "total_traffic_criteria" then
    criteria = traffic_criteria.TOTAL
elseif criteria_as == "ingress_traffic_criteria" then
    criteria = traffic_criteria.INGRESS
else
    criteria = traffic_criteria.ING_EGR
end

-- ################################################

if isEmptyString(ifid) then
    rc = rest_utils.consts.err.invalid_interface
    rest_utils.answer(rc)
    return
end

-- ################################################

local node_ids = {}
local last_node_id = 0
local debug = false

function find_node_id(node)
    local rc = node_ids[node]

    if (rc == nil) then
        rc = last_node_id .. ""
        last_node_id = last_node_id + 1
        node_ids[node] = rc

        if (debug) then tprint("Adding " .. node .. " as " .. rc) end

        return (rc)
    else
        return (rc)
    end
end

-- ################################################

local rsp = {}
local nodes = {}
local links = {}
local node_set = {}
local as_root_key = "root";
local max_len = 32
local ifstats = interface.getStats()

table.insert(nodes, {
    link = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=" .. asn .. "",
    node_id = as_root_key,
    label = shortenString(format_utils.formatASN(asn), 64)
})

-- ####################

local function add_unique_node(node_id, label, link)
    if not node_set[node_id] then
        table.insert(nodes, {node_id = node_id, label = shortenString(label, 64), link = link})
        node_set[node_id] = true
    end
end

local function reset_nodes() node_set = {} end


local function search_probe(ip)
    for interface_id, probe_list in pairs(ifstats.probes or {}) do
        for probe_ip, probe_info in pairsByKeys(probe_list or {}) do
            for exporter_ip, exporter_info in pairsByKeys(probe_info.exporters or {}) do
                if exporter_ip==ip then
                    return {probe_uuid = probe_info["probe.uuid_num"], exporter_uuid = exporter_info["unique_source_id"]}
                end
            end
        end
    end
end
-- ####################

-- Total bytes sent/rcvd per exporter (key = <device ip>)

local tot_bytes_exporter = {}

local function init_exporter(device_ip)
    local key = device_ip
    if not tot_bytes_exporter[key] then
        tot_bytes_exporter[key] = {sent = 0, rcvd = 0}
    end
end

local function inc_exporter_sent(key, bytes)
    tot_bytes_exporter[key].sent = tot_bytes_exporter[key].sent + bytes
end

local function inc_exporter_rcvd(key, bytes)
    tot_bytes_exporter[key].rcvd = tot_bytes_exporter[key].rcvd + bytes
end

-- Total bytes sent/rcvd per exporter/interface (key = <device ip>@<if index>)

local tot_bytes_exp_if = {}

local function get_interface_key(device_ip, interface_index)
    return device_ip .. "@" .. interface_index
end

local function init_interface(device_ip, interface_index)
    local key = get_interface_key(device_ip, interface_index)
    if not tot_bytes_exp_if[key] then
        tot_bytes_exp_if[key] = {
            sent = 0,
            rcvd = 0,
            exporter_ip = device_ip,
            port_index = interface_index
        }
    end
end

local function inc_interface_sent(key, bytes)
    tot_bytes_exp_if[key].sent = tot_bytes_exp_if[key].sent + bytes
end

local function inc_interface_rcvd(key, bytes)
    tot_bytes_exp_if[key].rcvd = tot_bytes_exp_if[key].rcvd + bytes
end

local function build_interface_exporter(criteria, tot_bytes_exp_if,
                                        exporter_nodes)
    for n_id, data in pairs(tot_bytes_exp_if) do
        if (criteria == traffic_criteria.INGRESS and data.sent > 0) or
            (criteria == traffic_criteria.EGRESS and data.rcvd > 0) or
            (criteria == traffic_criteria.TOTAL and (data.rcvd + data.sent) > 0) then
            -- tprint(n_id .. " " .. criteria .. " " .. data.sent .. " " .. data.rcvd)
            local exporter_ip = getProbeName(data.exporter_ip)
            local port_index = format_portidx_name(data.exporter_ip,
                                                   data.port_index, true) or "?"
            local exporter_node_id = find_node_id(exporter_ip)
            local port_node_id = find_node_id(n_id)

            if criteria == traffic_criteria.EGRESS then
                exporter_node_id = "egress" .. "_" .. exporter_node_id
                port_node_id = "egress" .. "_" .. port_node_id
            else
                exporter_node_id = "ingress" .. "_" .. exporter_node_id
                port_node_id = "ingress" .. "_" .. port_node_id
            end

            if (exporter_nodes[data.exporter_ip] == nil) then
                exporter_nodes[data.exporter_ip] = exporter_node_id
            end
            nprobe_stats = search_probe(data.exporter_ip)
            local url = "#"
            if ntop.isEnterprise() then 
                url = ntop.getHttpPrefix() ..
                        '/lua/pro/enterprise/exporter_details.lua?ip=' .. exporter_ip ..
                        '&exporter_uuid=' .. nprobe_stats.exporter_uuid ..
                        '&probe_uuid=' .. nprobe_stats.probe_uuid
            end
            add_unique_node(exporter_node_id, exporter_ip, url)
            url = "#"
            if ntop.isEnterprise() then 
                url = ntop.getHttpPrefix() .. 
                        '/lua/pro/enterprise/snmp_interface_details.lua?host='.. data.exporter_ip .. 
                        '&snmp_port_idx='.. data.port_index 
            end
            add_unique_node(port_node_id, port_index, url)

            if criteria == traffic_criteria.INGRESS then
                -- Interface -> Exporter
                table.insert(links, {
                    source_node_id = port_node_id,
                    target_node_id = exporter_node_id,
                    label = bytesToSize(data.sent),
                    value = data.sent
                })
            elseif criteria == traffic_criteria.EGRESS then
                -- Exporter -> Interface
                table.insert(links, {
                    source_node_id = exporter_node_id,
                    target_node_id = port_node_id,
                    label = bytesToSize(data.rcvd),
                    value = data.rcvd
                })
            elseif criteria == traffic_criteria.TOTAL then
                -- Interface -> Exporter
                table.insert(links, {
                    source_node_id = port_node_id,
                    target_node_id = exporter_node_id,
                    label = bytesToSize(data.rcvd + data.sent),
                    value = data.rcvd + data.sent
                })
            end

        end
    end
end

local function build_exporter_as(criteria, exporter_nodes)
    for exporter_ip, exporter_node_id in pairs(exporter_nodes) do
        local sent = tot_bytes_exporter[exporter_ip].sent
        local rcvd = tot_bytes_exporter[exporter_ip].rcvd

        if criteria == traffic_criteria.INGRESS and sent > 0 then
            -- Exporter -> AS
            table.insert(links, {
                source_node_id = exporter_node_id,
                target_node_id = as_root_key,
                label = bytesToSize(sent),
                value = sent
            })
        elseif criteria == traffic_criteria.EGRESS and rcvd > 0 then
            -- AS -> Exporter
            table.insert(links, {
                source_node_id = as_root_key,
                target_node_id = exporter_node_id,
                label = bytesToSize(rcvd),
                value = rcvd
            })
        elseif criteria == traffic_criteria.TOTAL then
            -- Exporter -> AS
            table.insert(links, {
                source_node_id = exporter_node_id,
                target_node_id = as_root_key,
                label = bytesToSize(rcvd + sent),
                value1 = rcvd + sent
            })
        end
    end
end

-- Flow iterator callback
function callback(_, flow)
    if (debug) then
        -- tprint(flow.bytes_sent .. " / " .. flow.bytes_rcvd)
        tprint("[AS] " .. flow.src_as .. " -> " .. flow.dst_as .. " | [IDX] " ..
                   flow.in_index .. " -> " .. flow.out_index .. " | " ..
                   flow.bytes_sent .. " / " .. flow.bytes_rcvd)
    end

    -- Initialize hash entries if not yet popupated
    init_exporter(flow.device_ip)
    init_interface(flow.device_ip, flow.in_index)
    init_interface(flow.device_ip, flow.out_index)

    if (flow.src_as == asn) then
        inc_interface_sent(get_interface_key(flow.device_ip, flow.in_index),
                           flow.bytes_rcvd)
        inc_interface_rcvd(get_interface_key(flow.device_ip, flow.in_index),
                           flow.bytes_sent)
        inc_exporter_sent(flow.device_ip, flow.bytes_rcvd)
        inc_exporter_rcvd(flow.device_ip, flow.bytes_sent)
    elseif (flow.dst_as == asn) then
        inc_interface_sent(get_interface_key(flow.device_ip, flow.out_index),
                           flow.bytes_sent)
        inc_interface_rcvd(get_interface_key(flow.device_ip, flow.out_index),
                           flow.bytes_rcvd)
        inc_exporter_sent(flow.device_ip, flow.bytes_sent)
        inc_exporter_rcvd(flow.device_ip, flow.bytes_rcvd)
    end
end

local flows_filter = {
    asnFilter = asn,
    detailsLevel = "normal",
    maxHits = 10000,
    perPage = 10000
}

callback_utils.foreachFlow(ifid, os.time() + 30, -- deadline
callback, flows_filter)

-- ###################################################

if (debug) then
    tprint(tot_bytes_exp_if)
    tprint(tot_bytes_exporter)
end

local exporter_nodes = {}

if (criteria ~= traffic_criteria.ING_EGR) then
    -- Build Interface <-> Exporter links
    build_interface_exporter(criteria, tot_bytes_exp_if, exporter_nodes)
    -- Build Exporter <-> AS links
    build_exporter_as(criteria, exporter_nodes)
else
    -- Ingress
    build_interface_exporter(traffic_criteria.INGRESS, tot_bytes_exp_if,
                             exporter_nodes)
    build_exporter_as(traffic_criteria.INGRESS, exporter_nodes)

    reset_nodes()
    exporter_nodes = {}

    -- Egress
    build_interface_exporter(traffic_criteria.EGRESS, tot_bytes_exp_if,
                             exporter_nodes)
    build_exporter_as(traffic_criteria.EGRESS, exporter_nodes)
end
rsp["nodes"] = nodes
rsp["links"] = links

rest_utils.answer(rest_utils.consts.success.ok, rsp)
