--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local json = require "dkjson"

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

local deviceIP    = _GET["deviceIP"]
local inIfIdx     = _GET["inIfIdx"]
local outIfIdx    = _GET["outIfIdx"]

local asn         = _GET["asn"]

local vhost       = _GET["vhost"]
local flowhosts_type  = _GET["flowhosts_type"]
local ipversion       = _GET["version"]
local traffic_type = _GET["traffic_type"]
local flow_status = _GET["flow_status"]

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
   end
end

if not isEmptyString(ipversion) then
   pageinfo["ipVersion"] = tonumber(ipversion)
end

if not isEmptyString(vlan) then
   pageinfo["vlanIdFilter"] = tonumber(vlan)
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
   if(not isEmptyString(flows_stats[key]["info"])) then
      info = shortenString(flows_stats[key]["info"])
   elseif(not isEmptyString(flows_stats[key]["icmp"])) then
      info = getICMPTypeCode(flows_stats[key]["icmp"])
   elseif(flows_stats[key]["proto.ndpi"] == "SIP") then
      info = getSIPInfo(flows_stats[key])
   elseif(flows_stats[key]["proto.ndpi"] == "RTP") then
      info = getRTPInfo(flows_stats[key])
   end
   flows_stats[key]["info"] = info

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

      -- Flow username
      local i, j
      if(value["moreinfo.json"] ~= nil) then
	 i, j = string.find(value["moreinfo.json"], '"57593":')
      end
      if(i ~= nil) then
	 has_user = string.sub(value["moreinfo.json"], j+2, j+3)
	 if(has_user == '""') then has_user = nil end
      end
      if(has_user ~= nil) then src_key = src_key .. " <i class='fa fa-user'></i>" end
      src_key = src_key .. "</A>"

      if(value["cli.port"] > 0) then
	 src_port=":<A HREF='"..ntop.getHttpPrefix().."/lua/port_details.lua?port=" .. value["cli.port"] .. "'>"..ntop.getservbyport(value["cli.port"], string.lower(value["proto.l4"])).."</A>"
      else
	 src_port=""
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
	 dst_port=":<A HREF='"..ntop.getHttpPrefix().."/lua/port_details.lua?port=" .. value["srv.port"] .. "'>"..ntop.getservbyport(value["srv.port"], string.lower(value["proto.l4"])).."</A>"
      else
	 dst_port=""
      end
   else
      dst_key = shortenString(stripVlan(srv_name))
      dst_port=":"..value["srv.port"]
   end

   record["column_key"] = "<A HREF='"
      ..ntop.getHttpPrefix().."/lua/flow_details.lua?flow_key="
      ..value["ntopng.key"]
      .."'><span class='label label-info'>Info</span></A>"
   record["key"] = value["ntopng.key"]

   local column_client = src_key
   local info = interface.getHostInfo(value["cli.ip"], value["cli.vlan"])

   if(info ~= nil) then
      column_client = column_client..getFlag(info["country"])
   end

   column_client = column_client..src_port
   record["column_client"] = column_client

   local column_server = dst_key
   info = interface.getHostInfo(value["srv.ip"], value["srv.vlan"])
   if(info ~= nil) then
      column_server = column_server..getFlag(info["country"])
   end

   column_server = column_server..dst_port
   record["column_server"] = column_server

   record["column_vlan"] = ''
   if((value["vlan"] ~= nil)) then
      record["column_vlan"] = value["vlan"]
   end

   local column_proto_l4 = ''

   if(interface.isPacketInterface()) then
      if(value["flow.status"] ~= 0) then
	 column_proto_l4 = "<i class='fa fa-warning fa-lg' style='color: orange;'"
	    .." title='"..string.gsub(getFlowStatus(value["flow.status"]), "<[^>]*>([^<]+)<.*", "%1")
	    .."'></i> "
      end
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
