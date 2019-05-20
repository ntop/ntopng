--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local format_utils = require("format_utils")
local json = require "dkjson"

local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')
local debug = false
local debug_process = false -- Show flow processed information

interface.select(ifname)
local ifstats = interface.getStats()
-- printGETParameters(_GET)

-- Table parameters
local currentPage = _GET["currentPage"]
local perPage     = _GET["perPage"]
local sortColumn  = _GET["sortColumn"]
local sortOrder   = _GET["sortOrder"]
local host_info   = url2hostinfo(_GET)
local port        = _GET["port"]
local application = _GET["application"]
local category    = _GET["category"]
local network_id  = _GET["network"]
local vlan        = _GET["vlan"]
local uid         = _GET["uid"]
local pid         = _GET["pid"]
local container   = _GET["container"]
local pod         = _GET["pod"]
local icmp_type   = _GET["icmp_type"]
local icmp_code   = _GET["icmp_cod"]

local deviceIP    = _GET["deviceIP"]
local inIfIdx     = _GET["inIfIdx"]
local outIfIdx    = _GET["outIfIdx"]

local asn         = _GET["asn"]

local vhost       = _GET["vhost"]
local flowhosts_type  = _GET["flowhosts_type"]
local ipversion       = _GET["version"]
local traffic_type = _GET["traffic_type"]
local flow_status = _GET["flow_status"]
local tcp_state   = _GET["tcp_flow_state"]
local traffic_profile = _GET["traffic_profile"]

-- System host parameters
local hosts  = _GET["hosts"]
local user   = _GET["username"]
local host   = _GET["host"]
local pid    = tonumber(_GET["pid"])
local name   = _GET["pid_name"]

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

local prefs = ntop.getPrefs()

if(network_id ~= nil) then
   network_id = tonumber(network_id)
end

if sortColumn == nil or sortColumn == "column_" or sortColumn == "" then
   sortColumn = getDefaultTableSort("flows")
elseif sortColumn ~= "column_" and  sortColumn ~= "" then
   tablePreferences("sort_flows",sortColumn)
else
   sortColumn = "column_client"
end

if sortOrder == nil then
  sortOrder = getDefaultTableSortOrder("flows")
elseif sortColumn ~= "column_" and sortColumn ~= "" then
  tablePreferences("sort_order_flows",sortOrder)
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number",perPage)
end

if(port ~= nil) then port = tonumber(port) end

local to_skip = (currentPage - 1) * perPage

-- io.write("->"..sortColumn.."/"..perPage.."/"..sortOrder.."/"..sortColumn.."\n")
interface.select(ifname)
local a2z = false
if(sortOrder == "desc") then a2z = false else a2z = true end

local pageinfo = {
   ["sortColumn"] = sortColumn, ["toSkip"] = to_skip, ["maxHits"] = perPage,
   ["a2zSortOrder"] = a2z,
   ["hostFilter"] = host,
   ["portFilter"] = port,
   ["LocalNetworkFilter"] = network_id
}

if application ~= nil and application ~= "" then
   pageinfo["l7protoFilter"] = interface.getnDPIProtoId(application)
end

if category ~= nil and category ~= "" then
   pageinfo["l7categoryFilter"] = interface.getnDPICategoryId(category)
end

if traffic_profile ~= nil then
   pageinfo["trafficProfileFilter"] = traffic_profile
end

if not isEmptyString(flowhosts_type) then
   if flowhosts_type == "local_origin_remote_target" then
      pageinfo["clientMode"] = "local"
      pageinfo["serverMode"] = "remote"
   elseif flowhosts_type == "local_only" then
      pageinfo["clientMode"] = "local"
      pageinfo["serverMode"] = "local"
   elseif flowhosts_type == "remote_origin_local_target" then
      pageinfo["clientMode"] = "remote"
      pageinfo["serverMode"] = "local"
   elseif flowhosts_type == "remote_only" then
      pageinfo["clientMode"] = "remote"
      pageinfo["serverMode"] = "remote"
   end
end

if not isEmptyString(traffic_type) then
   if traffic_type:contains("unicast") then
      pageinfo["unicast"] = true
   else
      pageinfo["unicast"] = false
   end

   if traffic_type:contains("one_way") then
      pageinfo["unidirectional"] = true
   end
end

if not isEmptyString(flow_status) then
   if flow_status == "normal" then
      pageinfo["alertedFlows"] = false
      pageinfo["filteredFlows"] = false
   elseif flow_status == "alerted" then
      pageinfo["alertedFlows"] = true
   elseif flow_status == "filtered" then
      pageinfo["filteredFlows"] = true
   else 
      pageinfo["statusFilter"] = tonumber(flow_status)
   end
end

if not isEmptyString(ipversion) then
   pageinfo["ipVersion"] = tonumber(ipversion)
end

if not isEmptyString(vlan) then
   pageinfo["vlanIdFilter"] = tonumber(vlan)
end

if not isEmptyString(uid) then
   pageinfo["uidFilter"] = tonumber(uid)
end

if not isEmptyString(pid) then
   pageinfo["pidFilter"] = tonumber(pid)
end

if not isEmptyString(container) then
   pageinfo["container"] = container
end

if not isEmptyString(pod) then
   pageinfo["pod"] = pod
end

if not isEmptyString(deviceIP) then
   pageinfo["deviceIpFilter"] = deviceIP

   if not isEmptyString(inIfIdx) then
      pageinfo["inIndexFilter"] = tonumber(inIfIdx)
   end

   if not isEmptyString(outIfIdx) then
      pageinfo["outIndexFilter"] = tonumber(outIfIdx)
   end
end

if not isEmptyString(asn) then
   pageinfo["asnFilter"] = tonumber(asn)
end

pageinfo["icmp_type"] = tonumber(icmp_type)
pageinfo["icmp_code"] = tonumber(icmp_code)

if not isEmptyString(tcp_state) then
   pageinfo["tcpFlowStateFilter"] = tcp_state
end

local flows_stats = interface.getFlowsInfo(host, pageinfo)
local total = flows_stats["numFlows"]
local flows_stats = flows_stats["flows"]

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
      info = getICMPTypeCode(flows_stats[key]["icmp"])
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
   flows_stats[key]["info"] = "<span title='"..alt_info.."'>"..info.."</span>"

   if(flows_stats[key]["profile"] ~= nil) then
      flows_stats[key]["info"] = "<span class='label label-primary'>"..flows_stats[key]["profile"].."</span> "..info
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

   if(value["cli.allowed_host"]) then
      src_key="<A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?" .. hostinfo2url(value,"cli").. "' data-toggle='tooltip' title='" ..cli_tooltip.. "' >".. shortenString(stripVlan(cli_name))
      if(value["cli.systemhost"] == true) then src_key = src_key .. "&nbsp;<i class='fa fa-flag'></i>" end

      src_key = src_key .. "</A>"

      if(value["cli.port"] > 0) then
	 src_port="<A HREF='"..ntop.getHttpPrefix().."/lua/port_details.lua?port=" .. value["cli.port"] .. "'>"..ntop.getservbyport(value["cli.port"], string.lower(value["proto.l4"])).."</A>"
      else
	 src_port=""
      end

      --record["column_client_process"] = flowinfo2process(value["client_process"], hostinfo2url(value,"cli"))
      src_process = flowinfo2process(value["client_process"], hostinfo2url(value,"cli"))

      if value["client_container"] and value["client_container"].id then
         record["column_client_container"] = '<a href="' .. ntop.getHttpPrefix() .. '/lua/flows_stats.lua?container=' .. value["client_container"].id .. '">' .. format_utils.formatContainer(value["client_container"]) .. '</a>'

         if value["client_container"]["k8s.pod"] then
            record["column_client_pod"] = '<a href="' .. ntop.getHttpPrefix() .. '/lua/containers_stats.lua?pod=' .. value["client_container"]["k8s.pod"] .. '">' .. shortenString(value["client_container"]["k8s.pod"]) .. '</a>'
         end
      end
   else
      src_key = shortenString(stripVlan(cli_name))
      src_port=":"..value["cli.port"]
   end

   if(value["srv.allowed_host"]) then
      dst_key="<A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?".. hostinfo2url(value,"srv").. "' data-toggle='tooltip' title='" ..srv_tooltip.. "' >".. shortenString(stripVlan(srv_name))
      if(value["srv.systemhost"] == true) then dst_key = dst_key .. "&nbsp;<i class='fa fa-flag'></i>" end
      dst_key = dst_key .. "</A>"

      if(value["srv.port"] > 0) then
	 dst_port="<A HREF='"..ntop.getHttpPrefix().."/lua/port_details.lua?port=" .. value["srv.port"] .. "'>"..ntop.getservbyport(value["srv.port"], string.lower(value["proto.l4"])).."</A>"
      else
	 dst_port=""
      end

      --record["column_server_process"] = flowinfo2process(value["server_process"], hostinfo2url(value,"srv"))
      dst_process = flowinfo2process(value["server_process"], hostinfo2url(value,"srv"))

      if value["server_container"] and value["server_container"].id then
         record["column_server_container"] = '<a href="' .. ntop.getHttpPrefix() .. '/lua/flows_stats.lua?container=' .. value["server_container"].id .. '">' .. format_utils.formatContainer(value["server_container"]) .. '</a>'

         if value["server_container"]["k8s.pod"] then
            record["column_server_pod"] = '<a href="' .. ntop.getHttpPrefix() .. '/lua/containers_stats.lua?pod=' .. value["server_container"]["k8s.pod"] .. '">' .. shortenString(value["server_container"]["k8s.pod"]) .. '</a>'
         end
      end
   else
      dst_key = shortenString(stripVlan(srv_name))
      dst_port=":"..value["srv.port"]
   end

   if(value["client_tcp_info"] ~= nil) then
      record["column_client_rtt"] = format_utils.formatMillis(value["client_tcp_info"]["rtt"])
   end
   if(value["server_tcp_info"] ~= nil) then
      record["column_server_rtt"] = format_utils.formatMillis(value["server_tcp_info"]["rtt"])
   end

   local column_key = "<A HREF='"
      ..ntop.getHttpPrefix().."/lua/flow_details.lua?flow_key="
      ..value["ntopng.key"]
      .."'><span class='label label-info'>Info</span></A>"
   if(have_nedge) then
     if (value["verdict.pass"]) then
       column_key = column_key.." <span title='"..i18n("flow_details.drop_flow_traffic_btn").."' class='label label-default block-badge' "..(ternary(isAdministrator(), "onclick='block_flow("..value["ntopng.key"]..");' style='cursor: pointer;'", "")).."><i class='fa fa-ban' /></span>"
     else
       column_key = column_key.." <span title='"..i18n("flow_details.flow_traffic_is_dropped").."' class='label label-danger block-badge'><i class='fa fa-ban' /></span>"
     end
   end
   record["column_key"] = column_key
   record["key"] = value["ntopng.key"]

   local column_client = src_key
   local info = interface.getHostInfo(value["cli.ip"], value["cli.vlan"])

   if(info ~= nil) then
      if(info.broadcast_domain_host) then
	  column_client = column_client.." <i class='fa fa-sitemap' title='"..i18n("hosts_stats.label_broadcast_domain_host").."'></i>"
      end
      
      if(info.dhcpHost) then
	 column_client = column_client.." <i class=\'fa fa-flash fa-lg\' aria-hidden=\'true\' title=\'DHCP Host\'></i>"
      end
      column_client = column_client..getFlag(info["country"])
   end

   column_client = string.format("%s%s%s %s",
				 column_client,
				 ternary(src_port ~= '', ':', ''),
				 src_port,
             src_process)
   if(value["verdict.pass"] == false) then
     column_client = "<strike>"..column_client.."</strike>"
   end

   record["column_client"] = column_client

   local column_server = dst_key
   info = interface.getHostInfo(value["srv.ip"], value["srv.vlan"])

   if(info ~= nil) then
      if(info.broadcast_domain_host) then
	 column_server = column_server.." <i class='fa fa-sitemap' title='"..i18n("hosts_stats.label_broadcast_domain_host").."'></i>"
      end
      
      if(info.dhcpHost) then
	 column_server = column_server.." <i class=\'fa fa-flash fa-lg\' aria-hidden=\'true\' title=\'DHCP Host\'></i>"
      end

      column_server = column_server..getFlag(info["country"])
   end

   column_server = string.format("%s%s%s %s",
				 column_server,
				 ternary(dst_port ~= '', ':', ''),
				 dst_port,
             dst_process)
   if(value["verdict.pass"] == false) then
     column_server = "<strike>"..column_server.."</strike>"
   end
   record["column_server"] = column_server

   record["column_vlan"] = ''
   if((value["vlan"] ~= nil)) then
      record["column_vlan"] = value["vlan"]
   end

   local column_proto_l4 = ''

   if(value["flow.status"] ~= 0) then
	 column_proto_l4 = "<i class='fa fa-warning' style='color: orange;'"
	    .." title='"..noHtml(getFlowStatus(value["flow.status"], flow2statusinfo(value)))
	    .."'></i> "
   end

   if value["proto.l4"] == "TCP" or value["proto.l4"] == "UDP" then
      if value["tcp.seq_problems"] == true then
	 local tcp_issues = ""
	 if value["cli2srv.out_of_order"] > 0 or value["srv2cli.out_of_order"] > 0 then
	    tcp_issues = tcp_issues.." Out-of-order"
	 end
	 if value["cli2srv.retransmissions"] > 0 or value["srv2cli.retransmissions"] > 0 then
	    tcp_issues = tcp_issues.." Retransmissions"
	 end
	 if value["cli2srv.lost"] > 0 or value["srv2cli.lost"] > 0 then
	    tcp_issues = tcp_issues.." Loss"
	 end

	 column_proto_l4 = column_proto_l4..'<span title=\'Issues detected:'..tcp_issues..'\'><font color=#B94A48>'..value["proto.l4"].."</font></span>"
      elseif value["flow_goodput.low"] == true then
	 column_proto_l4 = column_proto_l4.."<font color=#B94A48><span title='Low Goodput'>"..value["proto.l4"].."</span></font>"
      else
	 column_proto_l4 = column_proto_l4..value["proto.l4"]
      end
   else
      column_proto_l4 = column_proto_l4..value["proto.l4"]
   end
   if(value["verdict.pass"] == false) then
     column_proto_l4 = "<strike>"..column_proto_l4.."</strike>"
   end
   record["column_proto_l4"] = column_proto_l4

   local app = getApplicationLabel(value["proto.ndpi"])
   if(value["verdict.pass"] == false) then
      app = "<strike>"..app.."</strike>"
   end

   record["column_ndpi"] = "<A HREF='".. ntop.getHttpPrefix().."/lua/hosts_stats.lua?protocol=" .. value["proto.ndpi_id"] .."'>"..app.." " .. formatBreed(value["proto.ndpi_breed"]) .."</A>"
   record["column_duration"] = secondsToTime(value["duration"])
   record["column_bytes"] = bytesToSize(value["bytes"])..""

   local column_thpt = ''
   if(throughput_type == "pps") then
      column_thpt = column_thpt..pktsToSize(value["throughput_pps"]).. " "
   else
      column_thpt = column_thpt..bitsToSize(8*value["throughput_bps"]).. " "
   end

   if((value["throughput_trend_"..throughput_type] ~= nil)
      and (value["throughput_trend_"..throughput_type] > 0)) then
      if(value["throughput_trend_"..throughput_type] == 1) then
	 column_thpt = column_thpt.."<i class='fa fa-arrow-up'></i>"
      elseif(value["throughput_trend_"..throughput_type] == 2) then
	 column_thpt = column_thpt.."<i class='fa fa-arrow-down'></i>"
      elseif(value["throughput_trend_"..throughput_type] == 3) then
	 column_thpt = column_thpt.."<i class='fa fa-minus'></i>"
      end
   end
   record["column_thpt"] = column_thpt

   local cli2srv = round((value["cli2srv.bytes"] * 100) / value["bytes"], 0)

   record["column_breakdown"] = "<div class='progress'><div class='progress-bar progress-bar-warning' style='width: " .. cli2srv .."%;'>Client</div><div class='progress-bar progress-bar-info' style='width: " .. (100-cli2srv) .. "%;'>Server</div></div>"

   local info = value["info"]

   record["column_info"] = info

   formatted_res[#formatted_res + 1] = record

end -- for

if(sortColumn == nil) then
   sortColumn = ""
end

if(sortOrder == nil) then
   sortOrder = ""
end

local result = {}

result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = total
result["data"] = formatted_res
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result))
