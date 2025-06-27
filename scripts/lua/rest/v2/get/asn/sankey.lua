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

local traffic_criteria = {
   INGRESS = 0,
   EGRESS = 1,
   TOTAL = 2,
}

local criteria
if criteria_as == "egress_traffic_criteria" then
   criteria = traffic_criteria.EGRESS
elseif criteria_as == "total_traffic_criteria" then
   criteria = traffic_criteria.TOTAL
else
   criteria = traffic_criteria.INGRESS
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
   local n_id

   if(debug) then
      -- tprint(flow.bytes_sent .. " / " .. flow.bytes_rcvd)
      tprint("[AS] "..flow.src_as .. " -> " .. flow.dst_as.. " | [IDX] ".. flow.in_index .. " -> " .. flow.out_index .. " | ".. flow.bytes_sent .. " / " .. flow.bytes_rcvd)
   end

   -- (1) out index
   n_id = flow.device_ip .. "@" .. flow.out_index

   -- Nake sure the hash has been populated
   if(tot_bytes[n_id] == nil) then
      tot_bytes[n_id] = { sent = 0, rcvd = 0, exporter_ip = flow.device_ip, port_index = flow.out_index }
   end
   
   if(tot_bytes_exporter[flow.device_ip] == nil) then
      tot_bytes_exporter[flow.device_ip] = { sent = 0, rcvd = 0 }
   end
   
   if(flow.src_as == asn) then
      tot_bytes[n_id].sent = tot_bytes[n_id].sent + flow.bytes_rcvd
      tot_bytes_exporter[flow.device_ip].sent = tot_bytes_exporter[flow.device_ip].sent + flow.bytes_rcvd
      tot_bytes_exporter[flow.device_ip].rcvd = tot_bytes_exporter[flow.device_ip].rcvd + flow.bytes_sent
   elseif(flow.dst_as == asn) then
      tot_bytes[n_id].rcvd = tot_bytes[n_id].rcvd + flow.bytes_sent
      tot_bytes_exporter[flow.device_ip].sent = tot_bytes_exporter[flow.device_ip].sent + flow.bytes_rcvd
      tot_bytes_exporter[flow.device_ip].rcvd = tot_bytes_exporter[flow.device_ip].rcvd + flow.bytes_sent
   end   

   if(flow.in_index ~= flow.out_index) then
   --if(true) then
      -- (2) in index
      n_id = flow.device_ip .. "@" .. flow.in_index
      
      if(tot_bytes[n_id] == nil) then
	 tot_bytes[n_id] = { sent = 0, rcvd = 0, exporter_ip = flow.device_ip, port_index = flow.in_index }
      end
            
      if(flow.src_as == asn) then
	 tot_bytes[n_id].rcvd = tot_bytes[n_id].rcvd + flow.bytes_sent
      elseif(flow.dst_as == asn) then
	 tot_bytes[n_id].sent = tot_bytes[n_id].sent + flow.bytes_rcvd
      end
   end
end

local flows_filter = { asnFilter = asn, detailsLevel = "normal", maxHits = 10000, perPage = 10000 }
callback_utils.foreachFlow(ifid,
			   os.time()+30, -- deadline
			   callback, flows_filter)

-- ###################################################

if(debug) then
   tprint(tot_bytes)
   tprint(tot_bytes_exporter)
end

local exporter_nodes = {}

for n_id, data in pairs(tot_bytes) do
   if (criteria == traffic_criteria.INGRESS and data.sent > 0) or 
         (criteria == traffic_criteria.EGRESS and data.rcvd > 0) or
      (criteria == traffic_criteria.TOTAL and data.rcvd+data.sent > 0) then
      local exporter_ip = getProbeName(data.exporter_ip)
      local port_index = format_portidx_name(data.exporter_ip, data.port_index) or "?"
      local exporter_node_id = find_node_id(exporter_ip)
      if(exporter_nodes[data.exporter_ip] == nil) then exporter_nodes[data.exporter_ip] = exporter_node_id end
      local port_node_id = find_node_id(n_id)
      add_unique_node(exporter_node_id, exporter_ip, "#")
      add_unique_node(port_node_id, port_index, "#")
      if criteria == traffic_criteria.INGRESS then
         table.insert(links, {
               source_node_id = port_node_id,
               target_node_id = exporter_node_id,
               label = bytesToSize(data.sent),
               value = data.sent 
         })
      elseif criteria == traffic_criteria.EGRESS then
         table.insert(links, {
               source_node_id = exporter_node_id,
               target_node_id = port_node_id,
               label = bytesToSize(data.rcvd),
               value = data.rcvd
         })
      else
         table.insert(links, {
               source_node_id = port_node_id,
               target_node_id = exporter_node_id,
               label = bytesToSize(data.rcvd+data.sent),
               value = data.rcvd+data.sent
         })
      end
   end
end
for exporter_ip, exporter_node_id in pairs(exporter_nodes) do
   local sent = tot_bytes_exporter[exporter_ip].sent
   local rcvd = tot_bytes_exporter[exporter_ip].rcvd
   if criteria == traffic_criteria.INGRESS and sent > 0 then
      table.insert(links, {
            source_node_id = exporter_node_id,
            target_node_id = as_root_key,
            label = bytesToSize(sent),
            value = sent
      })
   elseif criteria == traffic_criteria.EGRESS and rcvd > 0 then
      table.insert(links, {
            source_node_id = as_root_key,
            target_node_id = exporter_node_id,
            label = bytesToSize(rcvd),
            value = rcvd
      })
   else
      table.insert(links, {
            source_node_id = exporter_node_id,
            target_node_id = as_root_key,
            label = bytesToSize(rcvd+sent),
            value = rcvd+sent
      })
   end
end

rsp["nodes"] = nodes
rsp["links"] = links

rest_utils.answer(rest_utils.consts.success.ok, rsp)
