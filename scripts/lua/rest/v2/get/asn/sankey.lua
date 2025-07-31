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
if ntop.isPro() then
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
end


require "lua_utils"
require "flow_utils"
require "label_utils"
local as_utils = require "as_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local format_utils = require "format_utils"
local info = ntop.getInfo()
local callback_utils = require "callback_utils"
--local flow_as_utils = require "flow_as_historical_utils"

local epoch_begin = tonumber(_GET["epoch_begin"])
local epoch_end = tonumber(_GET["epoch_end"])

local flow_as_utils = require "flow_as_utils"
if (epoch_end ~= nil and epoch_end < os.time()) and ntop.isClickHouseEnabled() then
    flow_as_utils = require "flow_as_historical_utils"
end

local rc = rest_utils.consts.success.ok
local ifid = _GET["ifid"]
local criteria_as = _GET["criteria_as"]
local asn = tonumber(_GET["asn"])

local rsp = {}

local edges = {}
local nodes = {}

local traffic_criteria = {INGRESS = 0, EGRESS = 1, TOTAL = 2, ING_EGR = 3, AS_TRAFFIC = 4}
local node_type = {ASN = 0}

local criteria
local other_asns = "Other"
local other_node

if criteria_as == "traffic_between_ases" then
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

local function create_node_url(node, type)
    if type == node_type.ASN and node ~= "other" then 
        return ntop.getHttpPrefix() .. "/lua/as_overview.lua?asn=" .. node .. "&criteria_as=" .. criteria_as
    else
        return "#"
    end
end

local function create_node_label(node, type)
    if type == node_type.ASN and node ~= "other" then
        return format_utils.formatASN(tonumber(node), false, true)
    else
        return node
    end
end

-- ####################

-- REWORK
local tot_bytes_exporter = {}
local tot_bytes_exp_if = {}
-- REWORK


local sankey_table = {}

local function init_sankey_table(key, src_id, src, type_src, dst_id, dst, type_dst)
    if not sankey_table[key] then
        sankey_table[key] = {
            src_id = src_id,
            src = create_node_label(src, type_src),
            url_src = create_node_url(src, type_src),
            dst_id = dst_id,
            dst = create_node_label(dst, type_dst),
            url_dst = create_node_url(dst, type_dst),
            weight = 0,
        }
    end
end

-- ####################

local function inc_sankey_node(key, bytes)
    sankey_table[key].weight = sankey_table[key].weight + bytes
end

-- ####################

local function get_sankey_key(node_src, node_dst)
    return node_src .. "@" .. node_dst
end

-- ####################

-- create_sankey creates the nodes and links for the Sankey.
-- Node SRC_ID -> Node DST_ID
local function create_sankey(sankey_table)
    --tprint(sankey_table)
    for id, link in pairs(sankey_table) do
        if link.src_id ~= as_root_key then 
        add_unique_node(link.src_id, link.src, link.url_src) end
        if link.dst_id ~= as_root_key then
        add_unique_node(link.dst_id, link.dst, link.url_dst) end
        add_link(link.src_id,link.dst_id,bytesToSize(link.weight),link.weight)
    end
end

-- ####################
-- key: key used to reorder the table 
-- index: index of the reduced table
local function top_max_nodes(l, key, index)
    local sorted_list = {}
    for i, v in pairs(l) do
        table.insert(sorted_list, v)
    end
    table.sort(sorted_list, function(a, b)
        return tonumber(a[key]) > tonumber(b[key])
    end)
    local result = {}
    for i = 1, math.min(max_nodes, table.len(sorted_list)) do
        local entry = sorted_list[i]
        if entry[index] ~= nil then
            result[entry[index]] = entry
        end
    end
    return result
end

-- ####################
-- INGRESS_EGRESS

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
-- AS_VIEW

local function checkTransit(src_id, src, dst_id, dst, src_dst_as, src_dst_peer, bytes, criteria, top_transit)
    if(src_dst_peer ~= src_dst_as) then
        local transit = tonumber(src_dst_peer)
        if not top_transit[src_dst_peer] then transit = "other" end
        local transit_id
        if criteria == traffic_criteria.INGRESS then 
            transit_id = "ingress_transit_".. find_node_id(transit)
        else
            transit_id = "egress_transit_".. find_node_id(transit)
        end
        local key_transit = get_sankey_key(src_id, transit_id)
        init_sankey_table(key_transit, src_id, src, node_type.ASN, transit_id, transit, node_type.ASN)
        inc_sankey_node(key_transit, bytes)
        local key_dst = get_sankey_key(transit_id, dst_id)
        init_sankey_table(key_dst, transit_id, transit, node_type.ASN, dst_id, dst, node_type.ASN)
        inc_sankey_node(key_dst, bytes)
    else
        local key = get_sankey_key(src_id, dst_id)
        init_sankey_table(key, src_id, src, node_type.ASN, dst_id, dst, node_type.ASN)
        inc_sankey_node(key, bytes)
    end
end

-- build_as_view_ing_egr creates the ingress or egress part of the Sankey
-- Note: src/dst refers to the source/destination node of the Sankey, not the flows.
local function build_as_view_ing_egr(transit_traffic, criteria, top, top_transit)
    for id, data in pairs (transit_traffic) do
        if(criteria == traffic_criteria.INGRESS) and (data.bytes_rcvd ~= nil and tonumber(data.bytes_rcvd) > 0) then
            -- Check if dst_as is in the top_sent; otherwise, insert it into the other node.
            local src = data.dst_as
            if not top[src] then 
                src = "other"
            end
            local src_id = "ingress_" .. find_node_id(src)
            local dst = data.src_as
            local dst_id = as_root_key
            checkTransit(src_id, src, dst_id, dst, data.dst_as, data.dst_peer_as, tonumber(data.bytes_rcvd), criteria, top_transit)
        elseif (criteria == traffic_criteria.EGRESS) and (data.bytes_sent ~= nil and tonumber(data.bytes_sent) > 0) then
            local dst = data.src_as
            if not top[dst] then 
                dst = "other"
            end
            local dst_id = "egress_" .. find_node_id(dst)
            local src = data.dst_as
            local src_id = as_root_key
            checkTransit(src_id, src, dst_id, dst, data.src_as, data.src_peer_as, tonumber(data.bytes_sent), criteria, top_transit)
        end
    end
end

-- ###################################################

if (sankey_debug) then
   tprint(tot_bytes_exp_if)
   tprint(tot_bytes_exporter)
end


-- If the criteria is ING_EGR, the Sankey will consist of two parts:
-- ingress: ingress interface -> exporter -> AS;
-- egress: AS -> exporter -> egress interface.
-- It is necessary to create the links interface<->exporter and then exporter<->AS root.
if (criteria == traffic_criteria.ING_EGR) then
    tot_bytes_exporter = flow_as_utils.getExporter(asn, ifid)
    tot_bytes_exp_if = flow_as_utils.getExporterIf(as, ifid)
    local exporter_nodes = {}
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
    local transit_traffic_ingress = flow_as_utils.getAsTransit(asn, ifid, traffic_criteria.INGRESS, epoch_begin, epoch_end)
    local transit_traffic_egress = flow_as_utils.getAsTransit(asn, ifid, traffic_criteria.EGRESS, epoch_begin, epoch_end)
    -- top_sent and top_rcvd are necessary for the other node
    local top_sent = top_max_nodes(transit_traffic_ingress, "bytes_rcvd", "dst_as")
    local top_rcvd = top_max_nodes(transit_traffic_egress, "bytes_sent", "src_as")
    -- transit_list_ingress and transit_list_egress are necessary for the transit other node.
    local transit_list_ingress = flow_as_utils.getTransitList(asn, ifid, traffic_criteria.INGRESS, epoch_begin, epoch_end)
    local transit_list_egress = flow_as_utils.getTransitList(asn, ifid, traffic_criteria.EGRESS, epoch_begin, epoch_end)
    local top_sent_transit = top_max_nodes(transit_list_ingress, "bytes_rcvd", "dst_peer_as")
    local top_rcvd_transit = top_max_nodes(transit_list_egress, "bytes_sent", "src_peer_as")
    
    build_as_view_ing_egr(transit_traffic_ingress, traffic_criteria.INGRESS, top_sent, top_sent_transit)
    create_sankey(sankey_table)
    reset_nodes()
    sankey_table = {}
    build_as_view_ing_egr(transit_traffic_egress, traffic_criteria.EGRESS, top_rcvd, top_rcvd_transit)
    create_sankey(sankey_table)
end
rsp["nodes"] = nodes
rsp["links"] = links

rest_utils.answer(rest_utils.consts.success.ok, rsp)