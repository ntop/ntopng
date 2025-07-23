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
local as_utils = require "as_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local format_utils = require "format_utils"
local info = ntop.getInfo()
local callback_utils = require "callback_utils"

local rc = rest_utils.consts.success.ok
local ifid = _GET["ifid"]
local criteria_as = _GET["criteria_as"]
local asn = tonumber(_GET["asn"])

-- Read the ASn preferences from Policy -> Network Configuration -> ASN
local customer_asn, sub_customer_asn, remote_asn = as_utils.getAllConfigurations()
local rsp = {}

local edges = {}
local nodes = {}

local traffic_criteria = {INGRESS = 0, EGRESS = 1, TOTAL = 2, ING_EGR = 3, AS_TRAFFIC = 4}

local criteria
local other_asns = "Other"
local other_node

if criteria_as == "as_traffic_criteria" then
   criteria = traffic_criteria.AS_TRAFFIC
else
   criteria = traffic_criteria.ING_EGR
end

-- If the ingress or egress part of the graph has fewer nodes than max_nodes, 
-- all nodes will be shown in the Sankey. Otherwise, only the nodes specified 
-- in "Relevant Remote ASNs" will be displayed, along with an other_asns node 
-- representing the sum of all the remaining ones.
local max_nodes = 15

-- If show_all is enabled, the max_nodes setting is ignored and all nodes are 
-- shown regardless of their number.
local show_all = false
-- ################################################

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

-- ################################################

local node_ids = {}
local last_node_id = 0
local sankey_debug = false

function find_node_id(node)
   local rc = node_ids[node]

   if (rc == nil) then
      rc = last_node_id .. ""
      last_node_id = last_node_id + 1
      node_ids[node] = rc

      if (sankey_debug) then tprint("Adding " .. node .. " as " .. rc) end

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
		label = format_utils.formatASN(asn, false, true)
})

-- ####################

local function add_unique_node(node_id, label, link)
   if not node_set[node_id] then
      table.insert(nodes, {node_id = node_id, label = shortenString(label, 64), link = link})
      node_set[node_id] = true
   end
end

-- ####################

local function reset_nodes() node_set = {} end

-- ####################

local function add_link(source_node_id, target_node_id, label, value)
   local insert = true
   for _, link in ipairs(links) do
      if link.source_node_id == source_node_id and link.target_node_id == target_node_id then
           link.value = link.value + value
           link.label = bytesToSize(link.value)
           insert = false
      end
   end
   if insert then
      table.insert(links, {
		   source_node_id = source_node_id,
		   target_node_id = target_node_id,
		   label = label,
		   value = value
      })
   end
end

-- ####################

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
local tot_bytes_transit = {}
local tot_bytes_as = {}

local function init_exporter(device_ip)
   local key = device_ip
   if not tot_bytes_exporter[key] then
      tot_bytes_exporter[key] = {sent = 0, rcvd = 0}
   end
end

local function init_transit(transit)
   local key = transit
   if not tot_bytes_transit[key] then
      tot_bytes_transit[key] = {sent = 0, rcvd = 0}
   end
end

local function init_as(as)
   local key = as
   if not tot_bytes_as[key] then
      tot_bytes_as[key] = {sent = 0, rcvd = 0}
   end
end

-- ####################

local function inc_exporter_sent(key, bytes)
   tot_bytes_exporter[key].sent = tot_bytes_exporter[key].sent + bytes
end

-- ####################

local function inc_exporter_rcvd(key, bytes)
   tot_bytes_exporter[key].rcvd = tot_bytes_exporter[key].rcvd + bytes
end

-- ####################

local function inc_transit_sent(key, bytes)
   tot_bytes_transit[key].sent = tot_bytes_transit[key].sent + bytes
end

-- ####################

local function inc_transit_rcvd(key, bytes)
   tot_bytes_transit[key].rcvd = tot_bytes_transit[key].rcvd + bytes
end

-- ####################

local function inc_as_sent(key, bytes)
   tot_bytes_as[key].sent = tot_bytes_as[key].sent + bytes
end

-- ####################

local function inc_as_rcvd(key, bytes)
   tot_bytes_as[key].rcvd = tot_bytes_as[key].rcvd + bytes
end

-- ####################
-- Total bytes sent/rcvd per exporter/interface (key = <device ip>@<if index>)

local tot_bytes_exp_if = {}

local tot_bytes_as_transit = {}

local function get_interface_key(device_ip, interface_index)
   return device_ip .. "@" .. interface_index
end

local function get_as_key(transit, src_dst_as)
   return transit .. "@" .. src_dst_as
end

-- ####################

local function top_max_nodes(l, criteria)
   local list = {}
   for id, data in pairs(l) do
      table.insert(list, { id = id, rcvd = data.rcvd, sent = data.sent })
   end

   if criteria == traffic_criteria.INGRESS then
      table.sort(list, function(a, b) return a.sent > b.sent end)
   else
      table.sort(list, function(a, b) return a.rcvd > b.rcvd end)
   end
   local reduced = {}
   for i = 1, math.min(max_nodes-1, table.len(list)) do
      local entry = list[i]
      reduced[entry.id] = {
        sent = entry.sent,
        rcvd = entry.rcvd
      }
   end
   return reduced
end

-- ####################

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

local function init_link_as_transit(transit, as)
   local key = get_as_key(transit, as)
   if not tot_bytes_as_transit[key] then
      tot_bytes_as_transit[key] = {
	 sent = 0,
	 rcvd = 0,
	 transit = transit,
	 src_dst_as = as
      }
   end
end

-- ####################

local function inc_interface_sent(key, bytes)
   tot_bytes_exp_if[key].sent = tot_bytes_exp_if[key].sent + bytes
end

-- ####################

local function inc_interface_rcvd(key, bytes)
   tot_bytes_exp_if[key].rcvd = tot_bytes_exp_if[key].rcvd + bytes
end

-- ####################

local function inc_link_as_transit_sent(key, bytes)
   tot_bytes_as_transit[key].sent = tot_bytes_as_transit[key].sent + bytes
end

-- ####################

local function inc_link_as_transit_rcvd(key, bytes)
   tot_bytes_as_transit[key].rcvd = tot_bytes_as_transit[key].rcvd + bytes
end

-- ####################

-- Builds the nodes and links of the Sankey between the interfaces and the exporters
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
	 if ntop.isEnterprise() and nprobe_stats then
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
	    add_link(port_node_id, exporter_node_id, bytesToSize(data.sent), data.sent)
	 elseif criteria == traffic_criteria.EGRESS then
	    -- Exporter -> Interface
	    add_link(exporter_node_id, port_node_id, bytesToSize(data.rcvd), data.rcvd)
	 elseif criteria == traffic_criteria.TOTAL then
	    -- Interface -> Exporter
	    add_link(port_node_id, exporter_node_id,
		     bytesToSize(data.rcvd + data.sent), data.rcvd + data.sent)
	 end
      end
   end
end

-- ####################

-- Builds the nodes and links of the Sankey between the source/destination 
-- autonomous systems and the transit autonomous systems
local function build_as_transit(criteria, tot_bytes_as_transit, transit_nodes)
   for n_id, data in pairs(tot_bytes_as_transit) do
      if (criteria == traffic_criteria.INGRESS and data.sent > 0) or
	 (criteria == traffic_criteria.EGRESS and data.rcvd > 0) or
	 (criteria == traffic_criteria.TOTAL and (data.rcvd + data.sent) > 0) then
	 local transit
         local src_dst_as
         if tot_bytes_as[data.src_dst_as] == nil then 
           src_dst_as = other_asns
         else
	   src_dst_as = format_utils.formatASN(data.src_dst_as, false, true) 
         end
         if tot_bytes_transit[data.transit] == nil then 
           transit = other_asns
         else
	   transit = format_utils.formatASN(data.transit, false, true)
         end
	 local transit_node_id
         if data.src_dst_as ~= data.transit then
            transit_node_id = find_node_id(transit)
         end
	 local src_dst_as_id
	 if criteria == traffic_criteria.EGRESS then
            src_dst_as_id = find_node_id("egress" .. "_" .. src_dst_as)
            if data.src_dst_as ~= data.transit then
	       transit_node_id = "egress" .. "_" .. transit_node_id 
            end
	    src_dst_as_id = "egress" .. "_" .. src_dst_as_id
	 else
            src_dst_as_id = find_node_id("ingress" .. "_" .. src_dst_as)
            if data.src_dst_as ~= data.transit then
                transit_node_id = "ingress" .. "_" .. transit_node_id
            end
	    src_dst_as_id = "ingress" .. "_" .. src_dst_as_id
	 end
	 if transit_nodes[data.transit] == nil and data.src_dst_as ~= data.transit then
	    transit_nodes[data.transit] = transit_node_id
            if transit == other_asns then other_node = transit_node_id end
	 end
 
         local url =  ntop.getHttpPrefix() .. "/lua/as_overview.lua?asn=" .. data.src_dst_as .. "&criteria_as=" .. criteria_as
	 if src_dst_as == other_asns then url = "#" end
         add_unique_node(src_dst_as_id, src_dst_as, url)
	 if data.transit ~= data.src_dst_as then
            url =  ntop.getHttpPrefix() .. "/lua/as_overview.lua?asn=" .. data.transit .. "&criteria_as=" .. criteria_as
	    if transit == other_asns then url = "#" end
            add_unique_node(transit_node_id, transit, url)
	 end 
	 if criteria == traffic_criteria.INGRESS then
	    if data.transit ~= data.src_dst_as then
	       add_link(src_dst_as_id, transit_node_id, bytesToSize(data.sent), data.sent)
	    else
	       add_link(src_dst_as_id, as_root_key, bytesToSize(data.sent), data.sent)
	    end
	 elseif criteria == traffic_criteria.EGRESS then
	    if data.transit ~= data.src_dst_as then
	       add_link(transit_node_id, src_dst_as_id, bytesToSize(data.rcvd), data.rcvd)
	    else
	       add_link(as_root_key, src_dst_as_id, bytesToSize(data.rcvd), data.rcvd)
	    end
	 elseif criteria == traffic_criteria.TOTAL then
	    if data.src_dst_as then
	       add_link(src_dst_as_id, transit_node_id,
	 		bytesToSize(data.rcvd + data.sent), data.rcvd + data.sent)
	    else
	       add_link(src_dst_as_id, as_root_key,
	 		bytesToSize(data.rcvd + data.sent), data.rcvd + data.sent)
	    end
         end
      end
   end
end

-- ####################

-- Builds the nodes and links of the Sankey that lead to the root,
-- the AS at the center of the Sankey. (exporter->AS)
local function build_to_as(criteria, nodes, tot_bytes)
   for id, node_id in pairs(nodes) do
      local sent = tot_bytes[id].sent
      local rcvd = tot_bytes[id].rcvd

      if criteria == traffic_criteria.INGRESS and sent > 0 then
	 add_link(node_id,as_root_key,bytesToSize(sent),sent)
      elseif criteria == traffic_criteria.EGRESS and rcvd > 0 then
	 add_link(as_root_key, node_id, bytesToSize(rcvd), rcvd)
      elseif criteria == traffic_criteria.TOTAL then
	 add_link(node_id, as_root_key, bytesToSize(rcvd + sent),rcvd + sent)
      end
   end
end

-- ####################

-- Builds the nodes and links of the Sankey that lead to the root,
-- the AS at the center of the Sankey. (transit->AS)
local function build_transit_as(criteria, nodes, tot_bytes)
   for id, node_id in pairs(nodes) do
      local sent = tot_bytes[id].sent
      local rcvd = tot_bytes[id].rcvd

      if criteria == traffic_criteria.INGRESS and sent > 0 then
         if tot_bytes_transit[id] ~= nil then
	    add_link(node_id,as_root_key,bytesToSize(sent),sent)
         else
            add_link(other_node,as_root_key,bytesToSize(sent),sent)
         end
      elseif criteria == traffic_criteria.EGRESS and rcvd > 0 then
         if tot_bytes_transit[id] ~= nil then
	    add_link(as_root_key, node_id, bytesToSize(rcvd), rcvd)
         else
            add_link(as_root_key, other_node, bytesToSize(rcvd), rcvd)
         end
      elseif criteria == traffic_criteria.TOTAL then
	 add_link(node_id, as_root_key, bytesToSize(rcvd + sent),rcvd + sent)
      end
   end
end

-- ####################

local function build_as_traffic(criteria)
   local transit_nodes = {}
   local tot_bytes_transit_aux = tot_bytes_transit
   local tot_bytes_as_aux = tot_bytes_as

   if(table.len(tot_bytes_transit) > max_nodes) then
     -- order and reduce the transit list
     tot_bytes_transit = top_max_nodes(tot_bytes_transit, criteria)
   end
   if(table.len(tot_bytes_as) > max_nodes) then
     -- order and reduce the as list
     tot_bytes_as = top_max_nodes(tot_bytes_as, criteria)
   end

   build_as_transit(criteria, tot_bytes_as_transit, transit_nodes)
   build_transit_as(criteria, transit_nodes, tot_bytes_transit_aux)

   reset_nodes()
   tot_bytes_transit = tot_bytes_transit_aux
   tot_bytes_as = tot_bytes_as_aux
end

-- ####################

local function callback_transit(src_dst_peer_as, src_dst_as, bytes_rcvd, bytes_sent)
   init_transit(src_dst_peer_as)
   init_as(src_dst_as)
   init_link_as_transit(src_dst_peer_as, src_dst_as)
   inc_link_as_transit_sent(get_as_key(src_dst_peer_as, src_dst_as), bytes_sent)
   inc_link_as_transit_rcvd(get_as_key(src_dst_peer_as, src_dst_as), bytes_rcvd)
   inc_as_sent(src_dst_as, bytes_sent)
   inc_as_rcvd(src_dst_as, bytes_rcvd)
   if (src_dst_peer_as ~= src_dst_as) then
      inc_transit_sent(src_dst_peer_as, bytes_sent)
      inc_transit_rcvd(src_dst_peer_as, bytes_rcvd)
   end
end
-- ####################

-- Flow iterator callback
function callback(_, flow)
   if (sankey_debug) then
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
     inc_interface_sent(get_interface_key(flow.device_ip, flow.in_index), flow.bytes_rcvd)
     inc_interface_rcvd(get_interface_key(flow.device_ip, flow.in_index), flow.bytes_sent)
     inc_exporter_sent(flow.device_ip, flow.bytes_rcvd)
     inc_exporter_rcvd(flow.device_ip, flow.bytes_sent)
     -- Initialize transit
     if(flow.src_peer_as ~= nil) and (flow.dst_as ~= nil) and 
        (flow.src_peer_as ~= flow.dst_as) and (flow.src_peer_as ~= flow.src_as) then
           callback_transit(flow.src_peer_as, flow.dst_as, flow.bytes_sent, flow.bytes_rcvd)
     elseif((flow.dst_peer_as ~= nil) and (flow.dst_as ~= nil)) then
           callback_transit(flow.dst_peer_as, flow.dst_as, flow.bytes_sent, flow.bytes_rcvd)
     end

   elseif (flow.dst_as == asn) then
     inc_interface_sent(get_interface_key(flow.device_ip, flow.out_index), flow.bytes_sent)
     inc_interface_rcvd(get_interface_key(flow.device_ip, flow.out_index), flow.bytes_rcvd)
     inc_exporter_sent(flow.device_ip, flow.bytes_sent)
     inc_exporter_rcvd(flow.device_ip, flow.bytes_rcvd)
     if((flow.dst_peer_as ~= nil) and (flow.src_as ~= nil)) and
        (flow.dst_peer_as ~= flow.dst_as) and (flow.dst_peer_as ~= flow.src_as) then
           callback_transit(flow.dst_peer_as, flow.src_as, flow.bytes_rcvd, flow.bytes_sent) 
     elseif((flow.src_peer_as ~= nil) and (flow.src_as ~= nil)) then
           callback_transit(flow.src_peer_as, flow.src_as, flow.bytes_rcvd, flow.bytes_sent)
     end
   end
end

local flows_filter = {
   asnFilter = asn,
   detailsLevel = "normal",
}

callback_utils.foreachFlow(ifid, os.time() + 30, -- deadline
			   callback, flows_filter)

-- ###################################################

if (sankey_debug) then
   tprint(tot_bytes_exp_if)
   tprint(tot_bytes_exporter)
end

local exporter_nodes = {}

-- If the criteria is ING_EGR, the Sankey will consist of two parts:
-- ingress: ingress interface -> exporter -> AS;
-- egress: AS -> exporter -> egress interface.
-- It is necessary to create the links interface<->exporter and then exporter<->AS root.
if (criteria == traffic_criteria.ING_EGR) then
   -- Ingress
   build_interface_exporter(traffic_criteria.INGRESS, tot_bytes_exp_if,
			    exporter_nodes)
   build_to_as(traffic_criteria.INGRESS, exporter_nodes, tot_bytes_exporter)

   reset_nodes()
   exporter_nodes = {}

   -- Egress
   build_interface_exporter(traffic_criteria.EGRESS, tot_bytes_exp_if,
			    exporter_nodes)
   build_to_as(traffic_criteria.EGRESS, exporter_nodes, tot_bytes_exporter)

-- If the criteria is AS_TRAFFIC, the Sankey diagram will consist of two parts:
-- ingress: source AS -> transit AS -> AS;
-- egress: AS -> transit AS -> destination AS.
-- It is therefore necessary to create the links source/destination AS <-> transit AS and then transit AS <-> root AS.
elseif (criteria == traffic_criteria.AS_TRAFFIC) then
   build_as_traffic(traffic_criteria.INGRESS)
   build_as_traffic(traffic_criteria.EGRESS)
else
   -- Build Interface <-> Exporter links
   build_interface_exporter(criteria, tot_bytes_exp_if, exporter_nodes)
   -- Build Exporter <-> AS links
   build_exporter_as(criteria, exporter_nodes)
end
rsp["nodes"] = nodes
rsp["links"] = links

rest_utils.answer(rest_utils.consts.success.ok, rsp)