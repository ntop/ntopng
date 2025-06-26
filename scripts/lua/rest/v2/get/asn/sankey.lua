--
-- (C) 2013-25 - ntop.org
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

local unit
if criteria_as == "egress_traffic_criteria" then
   unit = "Egress"
elseif criteria_as == "total_traffic_criteria" then
   unit = "Total"
else
   unit = "Ingress"
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
		label = "ASN "..asn
})

-- ####################

local function add_unique_node(node_id, label, link)
   if not node_set[node_id] then
      table.insert(nodes, { node_id = node_id, label = label, link = link })
      node_set[node_id] = true
   end
end

-- ####################

local tot_bytes = {}
local tot_bytes_exporter = {}

function callback (_, flow)
   local exporter_ip = getProbeName(flow.device_ip) or "unknown"
   local port_index = format_portidx_name(flow.device_ip, flow.in_index) or "?"
   local n_id = exporter_ip .. "@" .. port_index

   if(tot_bytes[n_id] == nil) then tot_bytes[n_id] = { sent = 0, rcvd = 0 } end
   if(tot_bytes_exporter[exporter_ip] == nil) then tot_bytes_exporter[exporter_ip] = { sent = 0, rcvd = 0 } end
   
   if(flow.src_as == asn) then
      tot_bytes[n_id].sent = tot_bytes[n_id].sent + flow.bytes_sent
      tot_bytes_exporter[exporter_ip].sent = tot_bytes_exporter[exporter_ip].sent + flow.bytes_sent
   end

   if(flow.dst_as == asn) then
      tot_bytes[n_id].rcvd = tot_bytes[n_id].rcvd + flow.bytes_rcvd
      tot_bytes_exporter[exporter_ip].rcvd = tot_bytes_exporter[exporter_ip].rcvd + flow.bytes_rcvd
   end
end

local flows_filter = { asnFilter = asn, detailsLevel = "normal", maxHits = 10000, perPage = 10000 }
callback_utils.foreachFlow(ifid,
			   os.time()+30, -- deadline
			   callback, flows_filter)

local exporter_nodes = {}

for n_id, data in pairs(tot_bytes) do
   if (unit == "Ingress" and data.sent > 0) or 
         (unit == "Egress" and data.rcvd > 0) or
         (unit == "Total" and data.rcvd+data.sent > 0)then
      local exporter_ip, port_index = string.match(n_id, "([^@]+)@(.+)")
      local exporter_node_id = find_node_id(exporter_ip)
      if(exporter_nodes[exporter_ip] == nil) then exporter_nodes[exporter_ip] = exporter_node_id end
      local port_node_id = find_node_id(n_id)
      add_unique_node(exporter_node_id, exporter_ip, "#")
      add_unique_node(port_node_id, port_index, "#")
      if unit == "Ingress" then
         table.insert(links, {
               source_node_id = port_node_id,
               target_node_id = exporter_node_id,
               value = data.sent 
         })
      elseif unit == "Egress" then
         table.insert(links, {
               source_node_id = exporter_node_id,
               target_node_id = port_node_id,
               value = data.rcvd
         })
      else
         table.insert(links, {
               source_node_id = port_node_id,
               target_node_id = exporter_node_id,
               value = data.rcvd+data.sent
         })
      end
   end
end
for exporter_ip, exporter_node_id in pairs(exporter_nodes) do
   if unit == "Ingress" and tot_bytes_exporter[exporter_ip].sent > 0 then
      table.insert(links, {
            source_node_id = exporter_node_id,
            target_node_id = as_root_key,
            value = tot_bytes_exporter[exporter_ip].sent
      })
   elseif unit == "Egress" and tot_bytes_exporter[exporter_ip].rcvd > 0 then
      table.insert(links, {
            source_node_id = as_root_key,
            target_node_id = exporter_node_id,
            value = tot_bytes_exporter[exporter_ip].rcvd
      })
   else
      table.insert(links, {
            source_node_id = exporter_node_id,
            target_node_id = as_root_key,
            value = tot_bytes_exporter[exporter_ip].rcvd+tot_bytes_exporter[exporter_ip].sent
      })
   end
end

rsp["nodes"] = nodes
rsp["links"] = links

rest_utils.answer(rest_utils.consts.success.ok, rsp)
