--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

sendHTTPContentTypeHeader('text/html')
local debug = false
local debug_process = false -- Show flow processed information

interface.select(ifname)
local ifstats = interface.getStats()
-- printGETParameters(_GET)

-- Table parameters
local all = _GET["all"]
local currentPage = _GET["currentPage"]
local perPage     = _GET["perPage"]
local sortColumn  = _GET["sortColumn"]
local sortOrder   = _GET["sortOrder"]
local host_info   = url2hostinfo(_GET)
local port        = _GET["port"]
local application = _GET["application"]
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

to_skip = (currentPage-1) * perPage

if(all ~= nil) then
   perPage = 0
   currentPage = 0
end

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
   --print(pageinfo["l7protoFilter"].." / "..application)
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
flows_stats = flows_stats["flows"]

print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
-- tprint(flows_stats)
-- Prepare host
host_list = {}
num_host_list = 0
single_host = 0

if(hosts ~= nil) then host_list, num_host_list = getHostCommaSeparatedList(hosts) end
if(host ~= nil) then
   single_host = 1
   num_host_list = 1
end

vals = {}
num = 0

if(flows_stats == nil) then flows_stats = { } end

for key, value in ipairs(flows_stats) do
   -- io.write(">>>> "..key.."\n")
   if(debug) then io.write("==================\n") end

   process = true
   client_process = 0
   server_process = 0

   if(debug) then io.write("Cli:"..flows_stats[key]["cli.ip"].."\t") end
   if(debug) then io.write("Srv:"..flows_stats[key]["srv.ip"].."\n") end

   if(vhost ~= nil) then
      if((flows_stats[key]["cli.host"] ~= vhost)
      and (flows_stats[key]["srv.host"] ~= vhost)
   and (flows_stats[key]["protos.http.server_name"] ~= vhost)
   and (flows_stats[key]["protos.dns.last_query"] ~= vhost)) then
	 process = false
      end
   end

   if(network_id ~= nil) then
      process = process and ((flows_stats[key]["cli.network_id"] == network_id) or (flows_stats[key]["srv.network_id"] == network_id))
   end

   ---------------- L4 PROTO ----------------
   if(l4proto ~= nil) then
      process = process and (flows_stats[key]["proto.l4"] == l4proto)
   end
   if(debug and (not process)) then io.write("Stop L4\n") end

   ---------------- USER ----------------
   if(user ~= nil) then
      if(debug) then io.write("User:"..user.."\n") end

      if(flows_stats[key]["client_process"] ~= nil) then
         if(debug) then io.write("Client user:"..flows_stats[key]["client_process"]["user_name"].."\n") end
         if((flows_stats[key]["client_process"]["user_name"] == user)) then
            client_process = 1
         end
         if(debug) then io.write("USER: => ClientProcess -\t"..client_process.."\n") end
      end

      if(flows_stats[key]["server_process"] ~= nil) then
         if(debug) then io.write("Server user:"..flows_stats[key]["server_process"]["user_name"].."\n") end
         if((flows_stats[key]["server_process"]["user_name"] == user)) then
            server_process = 1
            if(debug) then io.write("USER: => 1ServerProcess -\t"..server_process.."\n") end
         end
         if(debug) then io.write("USER: => ServerProcess -\t"..server_process.."\n") end
      end

      process = process and ((client_process == 1) or (server_process == 1))

   end
   if(debug and (not process)) then io.write("Stop user\n") end

   ---------------- PID ----------------
   if(pid ~= nil) then
      if(debug) then io.write("Pid:"..pid.."\n") end

      if(flows_stats[key]["client_process"] ~= nil) then
         if(debug) then io.write("Client pid:"..flows_stats[key]["client_process"]["pid"].."\n") end
         if((flows_stats[key]["client_process"]["pid"] == pid)) then
            client_process = 1
         end
         if(debug) then io.write("PID: => ClientProcess -\t"..client_process.."\n") end
      end

      if(flows_stats[key]["server_process"] ~= nil) then
         if(debug) then io.write("Server pid:"..flows_stats[key]["server_process"]["pid"].."\n") end
         if((flows_stats[key]["server_process"]["pid"] == pid)) then
            server_process = 1
         end
         if(debug) then io.write("PID: => ServerProcess -\t"..server_process.."\n") end
      end

       process = process and  ((client_process == 1) or (server_process == 1))

   end
   if(debug and (not process)) then io.write("Stop Pid\n") end

   ---------------- NAME ----------------
   if(name ~= nil) then
      if(debug) then io.write("Name:"..name.."\n") end

      if(flows_stats[key]["client_process"] ~= nil) then
         if(debug) then io.write("Client name:"..flows_stats[key]["client_process"]["name"].."\n") end
         if((flows_stats[key]["client_process"]["name"] == name)) then
            client_process = 1
         end
         if(debug) then io.write("ClientProcess -\t"..client_process.."\n") end
      end

      if(flows_stats[key]["server_process"] ~= nil) then
         if(debug) then io.write("Server name:"..flows_stats[key]["server_process"]["name"].."\n") end
         if((flows_stats[key]["server_process"]["name"] == name)) then
            server_process = 1
         end
         if(debug) then io.write("ServerProcess -\t"..server_process.."\n") end
      end
      process = process and ((client_process == 1) or (server_process == 1))

   end
   if(debug and (not process)) then io.write("Stop name\n") end

   ---------------- PORT ----------------
   if(port ~= nil) then
      process = process and ((flows_stats[key]["cli.port"] == port) or (flows_stats[key]["srv.port"] == port))
   end
   if(debug and (not process)) then io.write("Stop port\n") end

   ---------------- HOST ----------------
   if((num_host_list > 0) and process) then
      if(single_host == 1) then
      if(debug) then io.write("Host:"..host_info["host"].."\n") end
      if(debug) then io.write("Cli:"..flows_stats[key]["cli.ip"].."\n") end
      if(debug) then io.write("Srv:"..flows_stats[key]["srv.ip"].."\n") end
      if(debug) then io.write("vlan:"..flows_stats[key]["vlan"].."  ".. host_info["vlan"].."\n") end

      process = process and ((flows_stats[key]["cli.ip"] == host_info["host"]) or (flows_stats[key]["srv.ip"] == host_info["host"]))
      process = process and (flows_stats[key]["vlan"] == host_info["vlan"])

      else
      cli_num = findStringArray(flows_stats[key]["cli.ip"],host_list)
      srv_num = findStringArray(flows_stats[key]["srv.ip"],host_list)

      if( (cli_num ~= nil) and (srv_num ~= nil) ) then
         if(cli_num and srv_num) then
            process = process and (flows_stats[key]["cli.ip"] ~= flows_stats[key]["srv.ip"])
         else
            process = process and false
         end
      else
         process = process and false
      end
      end
   end

   if(debug and (not process)) then io.write("Stop Host\n") end

   local info = ""
   if(flows_stats[key]["info"] ~= nil) then
      info = shortenString(flows_stats[key]["info"])
   elseif(flows_stats[key]["icmp"] ~= nil) then
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

   ---------------- TABLE SORTING ----------------
   -- TODO: as flows are returned already ordered via getFlowsInfo
   -- this table sorting shall be removed. However, there are special
   -- sort columns that I am not aware of, e.g., column_server_process
   if(process) then
      if(debug_process) then io.write("Flow Processing\n") end
      if(debug_process) then io.write("Cli: "..flows_stats[key]["cli.ip"].."\t") end
      if(debug_process) then io.write("Srv: "..flows_stats[key]["srv.ip"].."\n") end
      -- postfix is used to create a unique key otherwise entries with the same key will disappear
      num = num + 1
      if(sortColumn == "column_client") then
	 vkey = flows_stats[key]["cli.ip"]
      elseif(sortColumn == "column_server") then
	 vkey = flows_stats[key]["srv.ip"]
      elseif(sortColumn == "column_bytes") then
	 vkey = flows_stats[key]["bytes"]
      elseif(sortColumn == "column_vlan") then
	 vkey = flows_stats[key]["vlan"]
      elseif(sortColumn == "column_info") then
	 -- add spaces before postfix as we sort for string
	 vkey = flows_stats[key]["info"]
      elseif(sortColumn == "column_ndpi") then
	 vkey = flows_stats[key]["proto.ndpi"]
      elseif(sortColumn == "column_server_process") then
	 if(flows_stats[key]["server_process"] ~= nil) then
	    vkey = flows_stats[key]["server_process"]["name"]
	 else
	    vkey = ""
	 end
      elseif(sortColumn == "column_client_process") then
	 if(flows_stats[key]["client_process"] ~= nil) then
	    vkey = flows_stats[key]["client_process"]["name"]
	 else
	    vkey = ""
	 end
      elseif(sortColumn == "column_duration") then
	 vkey = flows_stats[key]["duration"]
      elseif(sortColumn == "column_thpt") then
	 vkey = flows_stats[key]["throughput_"..throughput_type]
      elseif(sortColumn == "column_proto_l4") then
	 vkey = flows_stats[key]["proto.l4"]
      else
	 -- By default sort by bytes
	 vkey = flows_stats[key]["bytes"]
      end

      --io.write("-->"..key.."="..vkey.."\n")
      -- vals[vkey] = key
      vals[key] = vkey
   end
end

num = 0

if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end

--[[ TODO: check that actually vals is no longer needed
for _key, _value in pairsByKeys(vals, funct) do
   key = vals[_key]
   value = flows_stats[key]
--]]
for _key, _value in pairsByValues(vals, funct) do
   value = flows_stats[_key]
   key = value["ntopng.key"]

     if(key ~= nil) then
      if((num < perPage) or (all ~= nil))then
   if(num > 0) then
      print ",\n"
   end

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
   i, j = nil
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

   print ("{ \"key\" : \"" .. value["ntopng.key"]..'\"')
   print (", \"column_key\" : \"<A HREF='"..ntop.getHttpPrefix().."/lua/flow_details.lua?flow_key=" .. value["ntopng.key"])
   print ("'><span class='label label-info'>Info</span></A>")
   print ("\", \"column_client\" : \"" .. src_key)

   info = interface.getHostInfo(value["cli.ip"])
   if(info ~= nil) then
      print(getFlag(info["country"]))
   end

   print(src_port)

   print ("\", \"column_server\" : \"" .. dst_key)

   info = interface.getHostInfo(value["srv.ip"])
   if(info ~= nil) then
      print(getFlag(info["country"]))
   end

   print(dst_port)

   if((value["vlan"] ~= nil)) then
      print("\", \"column_vlan\" : \""..value["vlan"].."\"")
   else
      print("\", \"column_vlan\" : \"\"")
   end

   -- if(value["category"] ~= nil) then print (", \"column_category\" : \"" .. value["category"] .. "\", ") else print (",") end
   print (", \"column_proto_l4\" : \"")

   if(interface.isPacketInterface()) then
      if(value["flow.status"] ~= 0) then
	 print("<i class='fa fa-warning fa-lg' style='color: orange;'"
		  .." title='"..string.gsub(getFlowStatus(value["flow.status"]), "<[^>]*>([^<]+)<.*", "%1")
		  .."'></i> ")
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
	 print('<span title=\'Issues detected:'..tcp_issues..'\'><font color=#B94A48>'..value["proto.l4"].."</font></span>")
      elseif value["flow_goodput.low"] == true then
	 print("<font color=#B94A48><span title='Low Goodput'>"..value["proto.l4"].."</span></font>")
      else
	 print(value["proto.l4"])
      end
   else
      print(value["proto.l4"])
   end

   app = getApplicationLabel(value["proto.ndpi"])
   if(value["verdict.pass"] == false) then
      app = "<strike>"..app.."</strike>"
   end
   print ("\", \"column_ndpi\" : \"<A HREF='".. ntop.getHttpPrefix().."/lua/hosts_stats.lua?protocol=" .. value["proto.ndpi_id"] .."'>"..app.." " .. formatBreed(value["proto.ndpi_breed"]) .."</A>")

   if(value["client_process"] ~= nil) then
      print ("\", \"column_client_process\" : \"")
      print("<A HREF='"..ntop.getHttpPrefix().."/lua/get_process_info.lua?pid=".. value["client_process"]["pid"] .."&pid_name="..value["client_process"]["name"].."&host="..value["cli.ip"].."'>" .. processColor(value["client_process"]).."</A>")
      print ("\", \"column_client_user_name\" : \"<A HREF='"..ntop.getHttpPrefix().."/lua/get_user_info.lua?username=" .. value["client_process"]["user_name"] .."&host="..value["cli.ip"].."'>" .. value["client_process"]["user_name"].."</A>")
   end
   if(value["server_process"] ~= nil) then
      print ("\", \"column_server_process\" : \"")
      print("<A HREF='"..ntop.getHttpPrefix().."/lua/get_process_info.lua?pid=".. value["server_process"]["pid"] .."&pid_name="..value["server_process"]["name"].."&host="..value["srv.ip"].."'>" .. processColor(value["server_process"]).."</A>")
      print ("\", \"column_server_user_name\" : \"<A HREF='"..ntop.getHttpPrefix().."/lua/get_user_info.lua?username=" .. value["server_process"]["user_name"] .."&host="..value["srv.ip"].."'>" .. value["server_process"]["user_name"].."</A>")
   end

   print ("\", \"column_duration\" : \"" .. secondsToTime(value["duration"]))
   print ("\", \"column_bytes\" : \"" .. bytesToSize(value["bytes"]) .. "")

   if(debug) then io.write ("throughput_type: "..throughput_type.."\n") end
   if((value["throughput_trend_"..throughput_type] ~= nil)
       and (value["throughput_trend_"..throughput_type] > 0)) then
      if(throughput_type == "pps") then
         print ("\", \"column_thpt\" : \"" .. pktsToSize(value["throughput_pps"]).. " ")
      else
         print ("\", \"column_thpt\" : \"" .. bitsToSize(8*value["throughput_bps"]).. " ")
      end

      if(value["throughput_trend_"..throughput_type] == 1) then
         print("<i class='fa fa-arrow-up'></i>")
         elseif(value["throughput_trend_"..throughput_type] == 2) then
         print("<i class='fa fa-arrow-down'></i>")
         elseif(value["throughput_trend_"..throughput_type] == 3) then
         print("<i class='fa fa-minus'></i>")
      end

      print("\"")
   else
      print ("\", \"column_thpt\" : \"0 "..throughput_type.." \"")
   end

   cli2srv = round((value["cli2srv.bytes"] * 100) / value["bytes"], 0)
   print (", \"column_breakdown\" : \"<div class='progress'><div class='progress-bar progress-bar-warning' style='width: " .. cli2srv .."%;'>Client</div><div class='progress-bar progress-bar-info' style='width: " .. (100-cli2srv) .. "%;'>Server</div></div>")

   print ("\", \"column_info\" : \"".. value["info"])

   if(prefs.is_categorization_enabled and (value["info"] ~= "") and (key ~= nil)) then
      flow = interface.findFlowByKey(tonumber(key))
      if(flow ~= nil) then value["category"] = flow["category"] end
      if(value["category"] ~= "") then
	 print(" ".. getCategoryIcon(value["info"], value["category"]))
      end
   end

   print(" \" }\n")

   num = num + 1
   end
end
end -- for

print ("\n], \"perPage\" : " .. perPage.. ",\n")

if(sortColumn == nil) then
   sortColumn = ""
end

if(sortOrder == nil) then
   sortOrder = ""
end

print ("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")
print ("\"totalRows\" : " .. total .. " \n}")
