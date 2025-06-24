--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
require "label_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local format_utils = require "format_utils"
local info = ntop.getInfo()
local snmp_cached_dev = require "snmp_cached_dev"
local snmp_utils = require "snmp_utils"

local rc = rest_utils.consts.success.ok
local ifid = _GET["ifid"]
local criteria_as = _GET["criteria_as"]
local asn = _GET["asn"]

local flows_filter = getFlowsFilter()
flows_filter["asn"] = asn  
local flows_stats = interface.getFlowsInfo(flows_filter["hostFilter"], flows_filter, flows_filter["talkingWith"],
                       flows_filter["client"], flows_filter["server"], flows_filter["flow_info"])

local unit
if criteria_as == "traffic_criteria" then
    unit = " Ingress"
else
    unit = " Egress"
end

-- For now only ingress
unit = " Ingress"

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

        if (debug) then
            tprint("Adding " .. node .. " as " .. rc)
        end

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

table.insert(nodes, {
    link = "/",
    node_id = as_root_key,
    label = "ASN"..asn
})

local function add_node_once(node_id, label, link)
    if not node_set[node_id] then
        table.insert(nodes, { node_id = node_id, label = label, link = link })
        node_set[node_id] = true
    end
end

for flow_id, flow in pairs(flows_stats.flows) do
    if type(flow) == "table" then
        if flow.dst_as == tonumber(asn) then
            local exporter_ip = getProbeName(flow.device_ip) or "unknown"
            local port_index = format_portidx_name(flow.device_ip,flow.in_index) or "?"
            local bytes = tonumber(flow.bytes) or 0

            local exporter_node_id = find_node_id(exporter_ip)
            local port_node_id = find_node_id(exporter_ip .. "_" .. port_index)

            add_node_once(exporter_node_id, exporter_ip, "#")
            add_node_once(port_node_id, exporter_ip .. "_" .. port_index, "#")

            table.insert(links, {
            source_node_id = port_node_id,
            target_node_id = exporter_node_id,
            value = bytes
            })

            table.insert(links, {
            source_node_id = exporter_node_id,
            target_node_id = as_root_key,
            value = bytes
            })
        end
    end
end

rsp["nodes"] = nodes
rsp["links"] = links

rest_utils.answer(rest_utils.consts.success.ok, rsp)
