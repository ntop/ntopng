--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local format_utils = require("format_utils")
local flow_consts = require "flow_consts"
local flow_utils = require "flow_utils"
local icmp_utils = require "icmp_utils"
local json = require "dkjson"

local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('application/json')
local debug = false
local debug_process = false -- Show flow processed information

local ifstats = interface.getStats()

-- System host parameters
local hosts  = _GET["hosts"]
local host   = _GET["host"] -- TODO: merge
local flows_to_update = _GET["custom_hosts"]

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()
local flows_filter = getFlowsFilter()
local flows_stats
local total = 0

if not flows_to_update then
   flows_stats = interface.getFlowsInfo(flows_filter["hostFilter"], flows_filter)
   total = flows_stats["numFlows"]
   flows_stats = flows_stats["flows"]
else
   flows_stats = {}

   -- Only update the requested rows
   for _, k in pairs(split(flows_to_update, ",")) do
      local flow_key_and_hash = string.split(k, "@") or {}

      if(#flow_key_and_hash == 2) then
         local flow = interface.findFlowByKeyAndHashId(tonumber(flow_key_and_hash[1]), tonumber(flow_key_and_hash[2]))

         if flow then
            flows_stats[#flows_stats + 1] = flow
         end
      end
   end
end

-- Prepare host
local host_list = {}
local num_host_list = 0
local single_host = 0

if(hosts ~= nil) then host_list, num_host_list = getHostCommaSeparatedList(hosts) end
if(host ~= nil) then
   single_host = 1
   num_host_list = 1
end

if(flows_stats == nil) then flows_stats = { } end

for key, value in ipairs(flows_stats) do
   local info = ""
   -- use an italic font to indicate extra information added after sorting
   local italic = true
   if(not isEmptyString(flows_stats[key]["info"])) then
      info = flows_stats[key]["info"]
      italic = false
   elseif(not isEmptyString(flows_stats[key]["icmp"])) then
      info = icmp_utils.get_icmp_label(ternary(isIPv4(flows_stats[key]["cli.ip"]), 4, 6), flows_stats[key]["icmp"]["type"], flows_stats[key]["icmp"]["code"])
   elseif(flows_stats[key]["proto.ndpi"] == "SIP") then
      info = getSIPInfo(flows_stats[key])
   elseif(flows_stats[key]["proto.ndpi"] == "RTP") then
      info = getRTPInfo(flows_stats[key])
   end

   -- safety checks against injections
   info = noHtml(info)
   info = info:gsub('"', '')
   local alt_info = info

   if italic then
      info = string.format("<i>%s</i>", info)
   end

   info = shortenString(info)

   flows_stats[key]["info"] = "<span data-toggle='tooltip' title='"..alt_info.."'>"..info.."</span>"

   if(flows_stats[key]["profile"] ~= nil) then
      flows_stats[key]["info"] = formatTrafficProfile(flows_stats[key]["profile"])..flows_stats[key]["info"]
   end
end

local formatted_res = {}

for _key, value in ipairs(flows_stats) do -- pairsByValues(vals, funct) do
   local record = {}
   local key = value["ntopng.key"]

   local srv_name = flowinfo2hostname(value, "srv")
   local cli_name = flowinfo2hostname(value, "cli")

   local src_port, dst_port = '', ''
   local src_process, dst_process = '', ''
   local src_container, dst_container = '', ''

   if(cli_name == nil) then cli_name = "???" end
   if(srv_name == nil) then srv_name = "???" end

   local cli_tooltip = cli_name:gsub("'","&#39;")
   local srv_tooltip = srv_name:gsub("'","&#39;")

   if((value["tcp.nw_latency.client"] ~= nil) and (value["tcp.nw_latency.client"] > 0)) then
      cli_tooltip = cli_tooltip.."&#10;nw latency: "..string.format("%.3f", value["tcp.nw_latency.client"]).." ms"
   end

   if((value["tcp.nw_latency.server"] ~= nil) and (value["tcp.nw_latency.server"] > 0)) then
      srv_tooltip = srv_tooltip.."&#10;nw latency: "..string.format("%.3f", value["tcp.nw_latency.server"]).." ms"
   end

   if value["cli.allowed_host"] and not ifstats.isViewed then
      local src_name = shortenString(stripVlan(cli_name))
      if(value["cli.systemhost"] == true) then src_name = src_name .. "&nbsp;<i class='fas fa-flag'></i>" end
      src_key = hostinfo2detailshref(flow2hostinfo(value, "cli"), nil, src_name, cli_tooltip)

      if value["cli.port"] > 0 then
	 src_port = "<A HREF='"..ntop.getHttpPrefix().."/lua/flows_stats.lua?port=" .. value["cli.port"]
	 if(host ~= nil) then src_port = src_port .. "&host="..host end
	 src_port = src_port .. "'>"..ntop.getservbyport(value["cli.port"], string.lower(value["proto.l4"])).."</A>"
      end

      --record["column_client_process"] = flowinfo2process(value["client_process"], hostinfo2url(value,"cli"))
      src_process   = flowinfo2process(value["client_process"], hostinfo2url(value,"cli"))
      src_container = flowinfo2container(value["client_container"])
   else
      src_key = shortenString(stripVlan(cli_name))

      if value["cli.port"] > 0 then
	 src_port = value["cli.port"]..''
      end
   end

   if value["srv.allowed_host"] and not ifstats.isViewed then
      local dst_name = shortenString(stripVlan(srv_name))
      if(value["srv.systemhost"] == true) then dst_name = dst_name .. "&nbsp;<i class='fas fa-flag'></i>" end
      dst_key = hostinfo2detailshref(flow2hostinfo(value, "srv"), nil, dst_name, srv_tooltip)

      if value["srv.port"] > 0 then
	 dst_port="<A HREF='"..ntop.getHttpPrefix().."/lua/flows_stats.lua?port=" .. value["srv.port"]
	 if(host ~= nil) then dst_port = dst_port .. "&host="..host end
	 dst_port = dst_port .. "'>"..ntop.getservbyport(value["srv.port"], string.lower(value["proto.l4"])).."</A>"
      else
	 dst_port=""
      end

      --record["column_server_process"] = flowinfo2process(value["server_process"], hostinfo2url(value,"srv"))
      dst_process   = flowinfo2process(value["server_process"], hostinfo2url(value,"srv"))
      dst_container = flowinfo2container(value["server_container"])

      if value["server_container"] and value["server_container"].id then
	 record["column_server_container"] = '<a href="' .. ntop.getHttpPrefix() .. '/lua/flows_stats.lua?container=' .. value["server_container"].id .. '">' .. format_utils.formatContainer(value["server_container"]) .. '</a>'

	 if value["server_container"]["k8s.pod"] then
	    record["column_server_pod"] = '<a href="' .. ntop.getHttpPrefix() .. '/lua/containers_stats.lua?pod=' .. value["server_container"]["k8s.pod"] .. '">' .. shortenString(value["server_container"]["k8s.pod"]) .. '</a>'
	 end
      end
   else
      dst_key = shortenString(stripVlan(srv_name))

      if value["srv.port"] > 0 then
	 dst_port = value["srv.port"]..""
      end
   end

   if(value["client_tcp_info"] ~= nil) then
      record["column_client_rtt"] = format_utils.formatMillis(value["client_tcp_info"]["rtt"])
   end
   if(value["server_tcp_info"] ~= nil) then
      record["column_server_rtt"] = format_utils.formatMillis(value["server_tcp_info"]["rtt"])
   end

   local column_key = "<A class='btn btn-sm btn-info' HREF='"
      ..ntop.getHttpPrefix().."/lua/flow_details.lua?flow_key="..value["ntopng.key"].."&flow_hash_id="..value["hash_entry_id"]
      .."'><i class='fas fa-search-plus'></i></A>"
   if(have_nedge) then
      if (value["verdict.pass"]) then
	 column_key = column_key.." <span title='"..i18n("flow_details.drop_flow_traffic_btn").."' class='badge badge-secondary block-badge' "..(ternary(isAdministrator(), "onclick='block_flow("..value["ntopng.key"]..", "..value["hash_entry_id"]..");' style='cursor: pointer;'", "")).."><i class='fas fa-ban' /></span>"
      else
	 column_key = column_key.." <span title='"..i18n("flow_details.flow_traffic_is_dropped").."' class='badge badge-danger block-badge'><i class='fas fa-ban' /></span>"
      end
   end
   record["column_key"] = column_key
   record["key"] = string.format("%u", value["ntopng.key"])
   record["hash_id"] = string.format("%u", value["hash_entry_id"])
   record["key_and_hash"] = string.format("%s@%s", record["key"], record["hash_id"])

   local column_client = src_key
   local info = interface.getHostInfo(value["cli.ip"], value["cli.vlan"])

   if info then
      if info.broadcast_domain_host then
	 column_client = column_client.." <i class='fas fa-sitemap fa-sm' title='"..i18n("hosts_stats.label_broadcast_domain_host").."'></i>"
      end

      if info.dhcpHost then
	 column_client = column_client.." <i class=\'fas fa-flash fa-sm\' title=\'DHCP Host\'></i>"
      end

      if info.is_blacklisted then
	 column_client = column_client.." <i class=\'fas fa-ban fa-sm\' title=\'"..i18n("hosts_stats.blacklisted").."\'></i>"
      end

      column_client = column_client..getFlag(info["country"])
   end

   column_client = string.format("%s%s%s %s %s",
				 column_client,
				 ternary(src_port ~= '', ':', ''),
				 src_port, src_process, src_container)

   if(value["verdict.pass"] == false) then
      column_client = "<strike>"..column_client.."</strike>"
   end

   record["column_client"] = column_client

   local column_server = dst_key
   info = interface.getHostInfo(value["srv.ip"], value["srv.vlan"])

   if info then
      if info.broadcast_domain_host then
	 column_server = column_server.." <i class='fas fa-sitemap fa-sm' title='"..i18n("hosts_stats.label_broadcast_domain_host").."'></i>"
      end

      if info.dhcpHost then
	 column_server = column_server.." <i class=\'fas fa-flash fa-sm\' title=\'DHCP Host\'></i>"
      end

      if info.is_blacklisted then
	 column_server = column_server.." <i class=\'fas fa-ban fa-sm\' title=\'"..i18n("hosts_stats.blacklisted").."\'></i>"
      end

      column_server = column_server..getFlag(info["country"])
   end

   column_server = string.format("%s%s%s %s %s",
				 column_server,
				 ternary(dst_port ~= '', ':', ''),
				 dst_port, dst_process, dst_container)
   if(value["verdict.pass"] == false) then
      column_server = "<strike>"..column_server.."</strike>"
   end
   record["column_server"] = column_server

   record["column_vlan"] = ''
   if((value["vlan"] ~= nil)) then
      record["column_vlan"] = value["vlan"]
   end

   local column_proto_l4 = ''
   if value["alerted_status"] then

      local status_info = flow_consts.getStatusDescription(value["alerted_status"], flow2statusinfo(value))
      column_proto_l4 = flow_consts.getStatusIcon(value["alerted_status"], status_info) -- "<i class='fas fa-exclamation-triangle' style=' title='"..noHtml(status_info) .."'></i> "
   elseif value["status_map"] and value["flow.status"] ~= flow_consts.status_types.status_normal.status_key then
      local title = ''

      for _, t in pairs(flow_consts.status_types) do
         local id = t.status_key
	 if ntop.bitmapIsSet(value["status_map"], id) then
	    if title ~= '' then
	       title = title..'\n'
	    end
	    title = title..flow_consts.getStatusDescription(id, flow2statusinfo(value))
	 end
      end

      column_proto_l4 = "<i class='fas fa-exclamation-circle' style='color: orange;' title='"..noHtml(title) .."'></i> "
   end

   column_proto_l4 = column_proto_l4..value["proto.l4"]

   if(value["verdict.pass"] == false) then
      column_proto_l4 = "<strike>"..column_proto_l4.."</strike>"
   end
   record["column_proto_l4"] = column_proto_l4

   local app = getApplicationLabel(value["proto.ndpi"])
   if(value["verdict.pass"] == false) then
      app = "<strike>"..app.."</strike>"
   end

   record["column_ndpi"] = app -- can't set the hosts_stats hyperlink for viewed interfaces
   if not ifstats.isViewed then
      record["column_ndpi"] = "<A HREF='".. ntop.getHttpPrefix().."/lua/hosts_stats.lua?protocol=" .. value["proto.ndpi_id"] .."'>"..app.." " .. formatBreed(value["proto.ndpi_breed"]) .."</A>"
   end
   record["column_duration"] = secondsToTime(value["duration"])
   record["column_bytes"] = value["bytes"]

   local column_thpt = ''
   if(throughput_type == "pps") then
      column_thpt = value["throughput_pps"]
   else
      column_thpt = 8 * value["throughput_bps"]
   end

if false then
   if((value["throughput_trend_"..throughput_type] ~= nil)
      and (value["throughput_trend_"..throughput_type] > 0)) then
      if(value["throughput_trend_"..throughput_type] == 1) then
	 column_thpt = column_thpt.."<i class='fas fa-arrow-up'></i>"
      elseif(value["throughput_trend_"..throughput_type] == 2) then
	 column_thpt = column_thpt.."<i class='fas fa-arrow-down'></i>"
      elseif(value["throughput_trend_"..throughput_type] == 3) then
	 column_thpt = column_thpt.."<i class='fas fa-minus'></i>"
      end
   end
end
   record["column_thpt"] = column_thpt

   local cli2srv = round((value["cli2srv.bytes"] * 100) / value["bytes"], 0)

   record["column_breakdown"] = "<div class='progress'><div class='progress-bar bg-warning' style='width: " .. cli2srv .."%;'>Client</div><div class='progress-bar bg-info' style='width: " .. (100-cli2srv) .. "%;'>Server</div></div>"

   local info = value["info"]

   if isScoreEnabled() then
      record["column_score"] = format_utils.formatValue(value.score.flow_score)
   end

   record["column_info"] = info

   formatted_res[#formatted_res + 1] = record

end -- for

local result = {
   perPage = flows_filter["perPage"],
   currentPage = flows_filter["currentPage"],
   totalRows = total,
   data = formatted_res,
   sort = {
      {flows_filter["sortColumn"],
       flows_filter["sortOrder"]}
   },
}

print(json.encode(result))
