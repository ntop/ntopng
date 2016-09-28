--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "historical_utils"
require "flow_utils"
require "voip_utils"

local json = require ("dkjson")

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
warn_shown = 0

function displayProc(proc)
   print("<tr><th width=30%>User Name</th><td colspan=2><A HREF="..ntop.getHttpPrefix().."/lua/get_user_info.lua?user=".. proc.user_name .."&".. hostinfo2url(flow,"cli")..">".. proc.user_name .."</A></td></tr>\n")
   print("<tr><th width=30%>Process PID/Name</th><td colspan=2><A HREF="..ntop.getHttpPrefix().."/lua/get_process_info.lua?pid=".. proc.pid .."&".. hostinfo2url(flow,"srv").. ">".. proc.pid .. "/" .. proc.name .. "</A>")
   print(" [son of <A HREF="..ntop.getHttpPrefix().."/lua/get_process_info.lua?pid=".. proc.father_pid .. ">" .. proc.father_pid .. "/" .. proc.father_name .."</A>]</td></tr>\n")

   if(proc.actual_memory > 0) then
      print("<tr><th width=30%>Average CPU Load</th><td colspan=2><span id=average_cpu_load_"..proc.pid..">")

      cpu_load = round(proc.average_cpu_load, 2)..""
      if(proc.average_cpu_load < 33) then
	     if(proc.average_cpu_load == 0) then proc.average_cpu_load = "< 1" end
		print("<font color=green>"..cpu_load.." %</font>")
	 elseif(proc.average_cpu_load < 66) then
		print("<font color=orange><b>"..cpu_load.." %</b></font>")
	 else
		print("<font color=red><b>"..cpu_load.." %</b></font>")
	 end
      print(" </span></td></tr>\n")

      print("<tr><th width=30%>I/O Wait Time Percentage</th><td colspan=2><span id=percentage_iowait_time_"..proc.pid..">")

      cpu_load = round(proc.percentage_iowait_time, 2)..""
      if(proc.percentage_iowait_time < 33) then
	     if(proc.percentage_iowait_time == 0) then proc.percentage_iowait_time = "< 1" end
		print("<font color=green>"..cpu_load.." %</font>")
	 elseif(proc.percentage_iowait_time < 66) then
		print("<font color=orange><b>"..cpu_load.." %</b></font>")
	 else
		print("<font color=red><b>"..cpu_load.." %</b></font>")
	 end
      print(" </span></td></tr>\n")


      print("<tr><th width=30%>Memory Actual / Peak</th><td colspan=2><span id=memory_"..proc.pid..">".. bytesToSize(proc.actual_memory) .. " / ".. bytesToSize(proc.peak_memory) .. " [" .. round((proc.actual_memory*100)/proc.peak_memory, 1) .."%]</span></td></tr>\n")
      print("<tr><th width=30%>VM Page Faults</th><td colspan=2><span id=page_faults_"..proc.pid..">")
      if(proc.num_vm_page_faults > 0) then
	 print("<font color=red><b>"..proc.num_vm_page_faults.."</b></font>")
      else
	 print("<font color=green>"..proc.num_vm_page_faults.."</font>")
      end
      print("</span></td></tr>\n")
   end

   if(proc.actual_memory == 0) then
      if(warn_shown == 0) then
	 warn_shown = 1
	 print('<tr><th colspan=2><i class="fa fa-warning fa-lg" style="color: #B94A48;"></i> Process information report is limited unless you use ntopng with <A HREF=http://www.ntop.org/products/nprobe/>nProbe</A> and the sprobe plugin</th></tr>\n')
	 end
   end
end

active_page = "flows"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

a = _GET["label"]

if((a ~= nil) and (a ~= "")) then
   patterns = {
      ['_'] = "",
      ['-_'] = " <i class=\"fa fa-exchange fa-lg\"></i> "
   }

   for search,replace in pairs(patterns) do
      a = string.gsub(a, search, replace)
   end
end

print [[

<div class="bs-docs-example">
	    <nav class="navbar navbar-default" role="navigation">
	      <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
	 <li><a href="#">Flow: ]] print(a) print [[ </a></li>
<li class="active"><a href="#">Overview</a></li>
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</div>
</div>
</nav>
]]

throughput_type = getThroughputType()

flow_key = _GET["flow_key"]

interface.select(ifname)
is_packetdump_enabled = isLocalPacketdumpEnabled()
if(flow_key == nil) then
   flow = nil
else
   flow = interface.findFlowByKey(tonumber(flow_key))
end
tprint(flow)
local ifid = interface.name2id(ifname)

if(flow == nil) then
   print('<div class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i> This flow cannot be found. '.. purgedErrorString()..'</div>')
else

   if(_GET["drop_flow_policy"] == "true") then
      interface.dropFlowTraffic(tonumber(flow_key))
      flow["verdict.pass"] = false
   end
   if(_GET["dump_flow_to_disk"] ~= nil and is_packetdump_enabled) then
      interface.dumpFlowTraffic(tonumber(flow_key), ternary(_GET["dump_flow_to_disk"] == "true", 1, 0))
      flow["dump.disk"] = ternary(_GET["dump_flow_to_disk"] == "true", true, false)
   end

   ifstats = interface.getStats()
   print("<table class=\"table table-bordered table-striped\">\n")
   if (ifstats.vlan and (flow["vlan"] ~= nil)) then
      print("<tr><th width=30%>")
      if(ifstats.sprobe) then
	 print('Source Id')
      else
	 print('VLAN ID')
      end

      print("</th><td colspan=2>" .. flow["vlan"].. "</td></tr>\n")
   end
     print("<tr><th width=30%>Flow Peers [ Client / Server ]</th><td colspan=2><A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?"..hostinfo2url(flow,"cli") .. "\">")
     print(flowinfo2hostname(flow,"cli",ifstats.vlan))
     if(flow["cli.systemhost"] == true) then print("&nbsp;<i class='fa fa-flag'></i>") end

   print("</A>")
   if(flow["cli.port"] > 0) then
      print(":<A HREF=\""..ntop.getHttpPrefix().."/lua/port_details.lua?port=" .. flow["cli.port"].. "\">" .. flow["cli.port"].."</A>")
   end
   if(flow["cli.mac"] ~= nil and flow["cli.mac"]~= "" and flow["cli.mac"] ~= "00:00:00:00:00:00") then
      print(" [ <A HREF=\""..ntop.getHttpPrefix().."/lua/hosts_stats.lua?mac=" .. flow["cli.mac"].. "\">" .. flow["cli.mac"].."</A> ]")
   end
   print("&nbsp; <i class=\"fa fa-exchange fa-lg\"></i> \n")

   print("<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?" .. hostinfo2url(flow,"srv") .. "\">")
   print(flowinfo2hostname(flow,"srv",ifstats.vlan))
   if(flow["srv.systemhost"] == true) then print("&nbsp;<i class='fa fa-flag'></i>") end
   print("</A>")
   if(flow["srv.port"] > 0) then
      print(":<A HREF=\""..ntop.getHttpPrefix().."/lua/port_details.lua?port=" .. flow["srv.port"].. "\">" .. flow["srv.port"].. "</A>")
   end
   if(flow["srv.mac"] ~= nil and flow["srv.mac"]~= "" and flow["srv.mac"] ~= "00:00:00:00:00:00") then
      print(" [ <A HREF=\""..ntop.getHttpPrefix().."/lua/hosts_stats.lua?mac=" .. flow["srv.mac"].. "\">" .. flow["srv.mac"].."</A> ]")
   end
   print("</td></tr>\n")

   print("<tr><th width=30%>Protocol</th>")
   if(ifstats.inline and flow["verdict.pass"]) then
      print("<td>")
   else
      print("<td colspan=2>")
   end

   if(flow["verdict.pass"] == false) then print("<strike>") end
   print(flow["proto.l4"].." / <A HREF=\""..ntop.getHttpPrefix().."/lua/")
   if((flow.client_process ~= nil) or (flow.server_process ~= nil))then	print("s") end
   print("flows_stats.lua?application=" .. flow["proto.ndpi"] .. "\">")
   print(getApplicationLabel(flow["proto.ndpi"]).." ("..flow["proto.ndpi_id"]..")")
   print("</A> ".. formatBreed(flow["proto.ndpi_breed"]))
   if(flow["verdict.pass"] == false) then print("</strike>") end
   historicalProtoHostHref(ifid, flow["cli.ip"], nil, flow["proto.ndpi_id"], flow["protos.ssl.certificate"])
   print("</td>")

   if(ifstats.inline) then
      print('<td>')
      if(flow["verdict.pass"]) then
	 print('<form class="form-inline" style="margin-bottom: 0px;"><input type="hidden" name="flow_key" value="'..flow_key..'">')
	 print('<input type="hidden" name="drop_flow_policy" value="true">')
	 print('<button style="position: relative; margin-top: 0; height: 26px" type="submit" class="btn btn-default btn-xs"><i class="fa fa-ban"></i> Drop Flow Traffic</button>')
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	 print('</form>')
      end

      print('</td>')
   end
   print("</tr>\n")

   if(ifstats.inline and (flow["shaper.cli2srv_a"] ~= nil)) then
      print("<tr><th width=30% rowspan=2>Flow Shapers</th>")
      c = flowinfo2hostname(flow,"cli",ifstats.vlan)
      s = flowinfo2hostname(flow,"srv",ifstats.vlan)

      shaper_key = "ntopng.prefs."..ifstats.id..".shaper_max_rate"

      cli_max_rate = ntop.getHashCache(shaper_key, flow["shaper.cli2srv_a"]) if(cli_max_rate == "") then cli_max_rate = -1 end
      srv_max_rate = ntop.getHashCache(shaper_key, flow["shaper.cli2srv_b"]) if(srv_max_rate == "") then srv_max_rate = -1 end
      max_rate = getFlowMaxRate(cli_max_rate, srv_max_rate)
      print("<td nowrap>"..c.." <i class='fa fa-arrow-right'></i> "..s.."</td><td>"..maxRateToString(max_rate).."</td></tr>")

      cli_max_rate = ntop.getHashCache(shaper_key, flow["shaper.srv2cli_a"]) if(cli_max_rate == "") then cli_max_rate = -1 end
      srv_max_rate = ntop.getHashCache(shaper_key, flow["shaper.srv2cli_b"]) if(srv_max_rate == "") then srv_max_rate = -1 end
      max_rate = getFlowMaxRate(cli_max_rate, srv_max_rate)
      print("<td nowrap>"..c.." <i class='fa fa-arrow-left'></i> "..s.."</td><td>"..maxRateToString(max_rate).."</td></tr>")
      print("</tr>")
   end


   print("<tr><th width=30%>First / Last Seen</th><td nowrap><div id=first_seen>" .. formatEpoch(flow["seen.first"]) ..  " [" .. secondsToTime(os.time()-flow["seen.first"]) .. " ago]" .. "</div></td>\n")
   print("<td nowrap><div id=last_seen>" .. formatEpoch(flow["seen.last"]) .. " [" .. secondsToTime(os.time()-flow["seen.last"]) .. " ago]" .. "</div></td></tr>\n")

   print("<tr><th width=30% rowspan=3>Total Traffic</th><td>Total: <span id=volume>" .. bytesToSize(flow["bytes"]) .. "</span> <span id=volume_trend></span></td>")
   if((ifstats.type ~= "zmq") and ((flow["proto.l4"] == "TCP") or (flow["proto.l4"] == "UDP")) and (flow["goodput_bytes"] > 0)) then
      print("<td><A HREF=https://en.wikipedia.org/wiki/Goodput>Goodput</A>: <span id=goodput_volume>" .. bytesToSize(flow["goodput_bytes"]) .. "</span> (<span id=goodput_percentage>")
      pctg = round(((flow["goodput_bytes"]*100)/flow["bytes"]), 2)
      if(pctg < 50) then
	 pctg = "<font color=red>"..pctg.."</font>"
      elseif(pctg < 60) then
	 pctg = "<font color=orange>"..pctg.."</font>"
      end
      print(pctg.."")

      print("</span> %) <span id=goodput_volume_trend></span> </td></tr>\n")
   else
      print("<td>&nbsp;</td></tr>\n")
   end

   print("<tr><td nowrap>Client <i class=\"fa fa-arrow-right\"></i> Server: <span id=cli2srv>" .. formatPackets(flow["cli2srv.packets"]) .. " / ".. bytesToSize(flow["cli2srv.bytes"]) .. "</span> <span id=sent_trend></span></td><td nowrap>Client <i class=\"fa fa-arrow-left\"></i> Server: <span id=srv2cli>" .. formatPackets(flow["srv2cli.packets"]) .. " / ".. bytesToSize(flow["srv2cli.bytes"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")

   print("<tr><td colspan=2>")
   cli2srv = round((flow["cli2srv.bytes"] * 100) / flow["bytes"], 0)

   cli_name = shortHostName(ntop.getResolvedAddress(flow["cli.ip"]))
   srv_name = shortHostName(ntop.getResolvedAddress(flow["srv.ip"]))

   if(flow["cli.port"] > 0) then
      cli_name = cli_name .. ":" .. flow["cli.port"]
      srv_name = srv_name .. ":" .. flow["srv.port"]
   end
   print('<div class="progress"><div class="progress-bar progress-bar-warning" style="width: ' .. cli2srv.. '%;">'.. cli_name..'</div><div class="progress-bar progress-bar-info" style="width: ' .. (100-cli2srv) .. '%;">' .. srv_name .. '</div></div>')
   print("</td></tr>\n")


   if(flow["tcp.nw_latency.client"] ~= nil) then
      s = flow["tcp.nw_latency.client"] + flow["tcp.nw_latency.server"]

      if(s > 0) then
	 print("<tr><th width=30%>Network Latency Breakdown</th><td colspan=2>")
	 cli2srv = round(((flow["tcp.nw_latency.client"] * 100) / s), 0)

	 c = string.format("%.3f", flow["tcp.nw_latency.client"])
	 print('<div class="progress"><div class="progress-bar progress-bar-warning" style="width: ' .. cli2srv.. '%;">'.. c ..' ms (client)</div>')

	 s = string.format("%.3f", flow["tcp.nw_latency.server"])
	 print('<div class="progress-bar progress-bar-info" style="width: ' .. (100-cli2srv) .. '%;">' .. s .. ' ms (server)</div></div>')
	 print("</td></tr>\n")
      end
   end

   if(flow["tcp.appl_latency"] ~= nil and flow["tcp.appl_latency"] > 0) then
   print("<tr><th width=30%>Application Latency</th><td colspan=2>"..msToTime(flow["tcp.appl_latency"]).."</td></tr>\n")
   end

   if((flow["cli2srv.packets"] > 1) and (flow["interarrival.cli2srv"]["max"] > 0)) then

   print("<tr><th width=30%")
   if(flow["flow.idle"] == true) then print(" rowspan=2") end
   print(">Packet Inter-Arrival Time<br>[ Min / Avg / Max ]</th><td nowrap>Client <i class=\"fa fa-arrow-right\"></i> Server: ")
   print(msToTime(flow["interarrival.cli2srv"]["min"]).." / "..msToTime(flow["interarrival.cli2srv"]["avg"]).." / "..msToTime(flow["interarrival.cli2srv"]["max"]))
   print("</td>\n")
   if(flow["srv2cli.packets"] < 2) then
     print("<td>&nbsp;")
   else
     print("<td nowrap>Client <i class=\"fa fa-arrow-left\"></i> Server: ")
     print(msToTime(flow["interarrival.srv2cli"]["min"]).." / "..msToTime(flow["interarrival.srv2cli"]["avg"]).." / "..msToTime(flow["interarrival.srv2cli"]["max"]))
   end
   print("</td></tr>\n")
   if(flow["flow.idle"] == true) then print("<tr><td colspan=2><i class='fa fa-clock-o'></i> <small>This looks like an <font color=red>idle flow</font> with periodic transmissions just to keep it alive.</small></td></tr>") end
   end

   if(flow["tcp.seq_problems"] ~= nil) then
      rowspan = 2
      if((flow["cli2srv.retransmissions"] + flow["srv2cli.retransmissions"]) > 0) then rowspan = rowspan+1 end
      if((flow["cli2srv.out_of_order"] + flow["srv2cli.out_of_order"]) > 0)       then rowspan = rowspan+1 end
      if((flow["cli2srv.lost"] + flow["srv2cli.lost"]) > 0)                       then rowspan = rowspan+1 end

      if(((flow["cli2srv.retransmissions"] + flow["srv2cli.retransmissions"])
            + (flow["cli2srv.out_of_order"] + flow["srv2cli.out_of_order"])
	    + (flow["cli2srv.lost"] + flow["srv2cli.lost"])) > 0) then
      print("<tr><th width=30% rowspan="..rowspan..">TCP Packet Analysis</th><td colspan=2 cellpadding='0' width='100%' cellspacing='0' style='padding-top: 0px; padding-left: 0px;padding-bottom: 0px; padding-right: 0px;'></tr>")
      print("<tr><th>&nbsp;</th><th>Client <i class=\"fa fa-arrow-right\"></i> Server / Client <i class=\"fa fa-arrow-left\"></i> Server</th></tr>\n")

      if((flow["cli2srv.retransmissions"] + flow["srv2cli.retransmissions"]) > 0) then
        print("<tr><th>Retransmissions</th><td align=right><span id=c2sretr>".. formatPackets(flow["cli2srv.retransmissions"]) .."</span> / <span id=s2cretr>".. formatPackets(flow["srv2cli.retransmissions"]) .."</span></td></tr>\n")
      end
      if((flow["cli2srv.out_of_order"] + flow["srv2cli.out_of_order"]) > 0) then
        print("<tr><th>Out of Order</th><td align=right><span id=c2sOOO>".. formatPackets(flow["cli2srv.out_of_order"]) .."</span> / <span id=s2cOOO>".. formatPackets(flow["srv2cli.out_of_order"]) .."</span></td></tr>\n")
      end
      if((flow["cli2srv.lost"] + flow["srv2cli.lost"]) > 0) then
        print("<tr><th>Lost</th><td align=right><span id=c2slost>".. formatPackets(flow["cli2srv.lost"]) .."</span> / <span id=s2clost>".. formatPackets(flow["srv2cli.lost"]) .."</span></td></tr>\n")
      end
      end
   end

   if(flow["protos.ssl.certificate"] ~= nil) then
      print("<tr><th width=30%><i class='fa fa-lock fa-lg'></i> SSL Certificate</th><td colspan=2>")
      print("<A HREF=\"http://"..flow["protos.ssl.certificate"].."\">"..flow["protos.ssl.certificate"].."</A> <i class=\"fa fa-external-link\"></i>")
      if(flow["category"] ~= nil) then print(" "..getCategoryIcon(flow["protos.ssl.certificate"], flow["category"])) end
      historicalProtoHostHref(ifid, nil, nil, nil, flow["protos.ssl.certificate"])
      print("</td></tr>\n")
   end

   if((flow["tcp.max_thpt.cli2srv"] ~= nil) and (flow["tcp.max_thpt.cli2srv"] > 0)) then
     print("<tr><th width=30%>"..
     '<a href="#" data-toggle="tooltip" title="Computed as TCP Window Size / RTT">'..
     "Max (Estimated) TCP Throughput</a><td nowrap> Client <i class=\"fa fa-arrow-right\"></i> Server: ")
     print(bitsToSize(flow["tcp.max_thpt.cli2srv"]))
     print("</td><td> Client <i class=\"fa fa-arrow-left\"></i> Server: ")
     print(bitsToSize(flow["tcp.max_thpt.srv2cli"]))
     print("</td></tr>\n")
	end

   if((flow["cli2srv.trend"] ~= nil) and false) then
     print("<tr><th width=30%>Througput Trend</th><td nowrap>"..flow["cli.ip"].." <i class=\"fa fa-arrow-right\"></i> "..flow["srv.ip"]..": ")
     print(flow["cli2srv.trend"])
     print("</td><td>"..flow["cli.ip"].." <i class=\"fa fa-arrow-left\"></i> "..flow["srv.ip"]..": ")
     print(flow["srv2cli.trend"])
     print("</td></tr>\n")
    end

   flags = flow["cli2srv.tcp_flags"] or flow["srv2cli.tcp_flags"]

   if((flags ~= nil) and (flags > 0)) then
      print("<tr><th width=30% rowspan=2>TCP Flags</th><td nowrap>Client <i class=\"fa fa-arrow-right\"></i> Server: ")
      printTCPFlags(flow["cli2srv.tcp_flags"])
      print("</td><td nowrap>Client <i class=\"fa fa-arrow-left\"></i> Server: ")
      printTCPFlags(flow["srv2cli.tcp_flags"])
      print("</td></tr>\n")

      print("<tr><td colspan=2>")

      flow_completed = false
      flow_reset = false
      flows_syn_seen = false
      resetter = ""

      if(hasbit(flags,0x01)) then flow_completed = true end
      if(hasbit(flags,0x02)) then flows_syn_seen = true end
      if(hasbit(flags,0x04)) then
         flow_completed = true
	 flow_reset = true

	 if(hasbit(flow["cli2srv.tcp_flags"],0x04)) then resetter = "client" else resetter = "server" end
     end

      if(flow_reset) then
	 print(" <small>This flow has been reset by "..resetter..".</small>")
      else
	 if(flow_completed) then
	    print(" <small>This flow is completed and will expire soon.</small>")
	 else
  	    print(" <small>We have not seen flow begin: peer roles (client/server) might be inaccurate.</small>")
	    if(not(flows_syn_seen)) then
	      print("")
	    else
	      print(" <small>This flow is active.</small>")
	    end
	 end
      end

      print("</td></tr>\n")
   end

   local icmp = flow["icmp"]
   if(icmp ~= nil) then
      print("<tr><th width=30%>ICMP Info</th><td colspan=2>".. getICMPTypeCode(icmp) .. "</td></tr>\n")
   end

   if interface.isPacketInterface() then
      print("<tr><th width=30%>Flow Status</th><td colspan=2>"..getFlowStatus(flow["flow.status"]).."</td></tr>\n")
   end

   if((flow.client_process == nil) and (flow.server_process == nil)) then
      print("<tr><th width=30%>Actual / Peak Throughput</th><td width=20%>")
      if (throughput_type == "bps") then
	 print("<span id=throughput>" .. bitsToSize(8*flow["throughput_bps"]) .. "</span> <span id=throughput_trend></span>")
      elseif (throughput_type == "pps") then
	 print("<span id=throughput>" .. pktsToSize(flow["throughput_bps"]) .. "</span> <span id=throughput_trend></span>")
      end

      if (throughput_type == "bps") then
	 print(" / <span id=top_throughput>" .. bitsToSize(8*flow["top_throughput_bps"]) .. "</span> <span id=top_throughput_trend></span>")
      elseif (throughput_type == "pps") then
	 print(" / <span id=top_throughput>" .. pktsToSize(flow["top_throughput_bps"]) .. "</span> <span id=top_throughput_trend></span>")
      end

      print("</td><td><span id=thpt_load_chart>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>")
      print("</td></tr>\n")
   else
      if((flow.client_process ~= nil) or (flow.server_process ~= nil)) then
	 print('<tr><th colspan=3><div id="sprobe"></div>')
	 width  = 1024
	 height = 200
	 url = ntop.getHttpPrefix().."/lua/sprobe_flow_data.lua?flow_key="..flow_key
	 dofile(dirs.installdir .. "/scripts/lua/inc/sprobe.lua")
	 print('</th></tr>\n')
      end

      if(flow.client_process ~= nil) then
	 print("<tr><th colspan=3 class=\"info\">Client Process Information</th></tr>\n")
	 displayProc(flow.client_process)
      end
      if(flow.server_process ~= nil) then
	 print("<tr><th colspan=3 class=\"info\">Server Process Information</th></tr>\n")
	 displayProc(flow.server_process)
      end
   end

   if(flow["protos.dns.last_query"] ~= nil) then
      print("<tr><th width=30%>DNS Query</th><td colspan=2>")
      if(string.ends(flow["protos.dns.last_query"], "arpa")) then
	 print(flow["protos.dns.last_query"])
      else
	 print("<A HREF=http://"..flow["protos.dns.last_query"]..">"..flow["protos.dns.last_query"].."</A> <i class='fa fa-external-link'></i>")
      end

      if(flow["category"] ~= nil) then
	 print(" "..getCategoryIcon(flow["protos.dns.last_query"], flow["category"]))
      end

      print("</td></tr>\n")
   end

   if(flow["bittorrent_hash"] ~= nil) then
      print("<tr><th>BitTorrent hash</th><td colspan=4><A HREF=\"https://www.google.it/search?q="..flow["bittorrent_hash"].."\">".. flow["bittorrent_hash"].."</A></td></tr>\n")
   end

   if(flow["protos.http.last_url"] ~= nil) then
      print("<tr><th width=30% rowspan=4>HTTP</th><th>HTTP Method</th><td>"..flow["protos.http.last_method"].."</td></tr>\n")
      print("<tr><th>Server Name</th><td>")
      if(flow["host_server_name"] ~= nil and flow["host_server_name"] ~= "") then
	 s = flow["host_server_name"]
      else
	 s = flowinfo2hostname(flow,"srv",ifstats.vlan)
      end
      print("<A HREF=http://"..s..">"..s.."</A> <i class=\"fa fa-external-link\">")
      if(flow["category"] ~= nil) then print(" "..getCategoryIcon(flow["host_server_name"], flow["category"])) end

      print("</td></tr>\n")
      print("<tr><th>URL</th><td>")

      if(flow["protos.http.last_url"] ~= "") then
	 print("<A HREF=\"http://"..s)
	 if(flow["srv.port"] ~= 80) then print(":"..flow["srv.port"]) end
	 print(flow["protos.http.last_url"].."\">"..shortenString(flow["protos.http.last_url"]).."</A> <i class=\"fa fa-external-link\">")
      else
	 print(shortenString(flow["protos.http.last_url"]))
      end

      print("</td></tr>\n")
      print("<tr><th>Response Code</th><td>"..flow["protos.http.last_return_code"].."</td></tr>\n")
   else
      if((flow["host_server_name"] ~= nil) and (flow["protos.dns.last_query"] == nil)) then
	 print("<tr><th width=30%>Server Name</th><td colspan=2><A HREF=http://"..flow["host_server_name"]..">"..flow["host_server_name"].."</A> <i class=\"fa fa-external-link\"></td></tr>\n")
      end
   end

   if(flow["profile"] ~= nil) then
      print("<tr><th width=30%><A HREF=".. ntop.getHttpPrefix() .."/lua/pro/admin/edit_profiles.lua>Profile Name</A></th><td colspan=2><span class='label label-primary'>"..flow["profile"].."</span></td></tr>\n")
   end

   if is_packetdump_enabled then
      dump_flow_to_disk = flow["dump.disk"]
      if(dump_flow_to_disk == true) then
	 dump_flow_to_disk_checked = 'checked="checked"'
	 dump_flow_to_disk_value = "false" -- Opposite
      else
	 dump_flow_to_disk_checked = ""
	 dump_flow_to_disk_value = "true" -- Opposite
      end

      print("<tr><th width=30%>Dump Flow Traffic</th><td colspan=2>")
      print [[
        <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
	  <input type="hidden" name="flow_key" value="]] print(flow_key .. '">')
      if _GET["label"] ~= nil and _GET["label"] ~= "" then
	 print('<input type="hidden" name="label" value="' .. _GET["label"] ..'">')
      end
      print('<input type="hidden" name="dump_flow_to_disk" value="'..dump_flow_to_disk_value..'"><input type="checkbox" value="1" '..dump_flow_to_disk_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i>')
      print(' </input>')
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print('</form>')
      print("</td></tr>\n")
   end

   if (flow["moreinfo.json"] ~= nil) then
      local info, pos, err = json.decode(flow["moreinfo.json"], 1, nil)

      -- get SIP rows
      if(ntop.isPro() and (flow["proto.ndpi"] == "SIP")) then
        local sip_table_rows = getSIPTableRows(info)
        print(sip_table_rows)
      end

      isThereSIP = 0
      if(ntop.isPro() and (flow["proto.ndpi"] == "SIP")) then
        isThereSIP = isThereProtocol(SIP, info)
        if(isThereSIP == 1) then
          isThereSIP = isThereSIPCall(info)
        end
      end
      info = removeProtocolFields("SIP",info)

      -- get RTP rows
      if(ntop.isPro() and (flow["proto.ndpi"] == "RTP")) then
        local rtp_table_rows = getRTPTableRows(info)
        print(rtp_table_rows)
      end

      isThereRTP = 0
      if(ntop.isPro() and (flow["proto.ndpi"] == "RTP")) then
        isThereRTP = isThereProtocol(RTP, info)
      end

      info = removeProtocolFields("RTP",info)

      num = 0

      for key,value in pairs(info) do
	 if(num == 0) then
	 print("<tr><th colspan=3 class=\"info\">Additional Flow Elements</th></tr>\n")
	 end

	 if(value ~= "") then
	      print("<tr><th width=30%>" .. getFlowKey(key) .. "</th><td colspan=2>" .. handleCustomFlowField(key, value) .. "</td></tr>\n")
	 end

	 num = num + 1
      end
   end
   print("</table>\n")
end

print [[
<script>
/*
      $(document).ready(function() {
	      $('.progress .bar').progressbar({ use_percentage: true, display_text: 1 });
   });
*/


var thptChart = $("#thpt_load_chart").peity("line", { width: 64 });
]]

if(flow ~= nil) then
   if (flow["cli2srv.packets"] ~= nil ) then
      print("var cli2srv_packets = " .. flow["cli2srv.packets"] .. ";")
   end
   if (flow["srv2cli.packets"] ~= nil) then
      print("var srv2cli_packets = " .. flow["srv2cli.packets"] .. ";")
   end
   if (flow["throughput_"..throughput_type] ~= nil) then
      print("var throughput = " .. flow["throughput_"..throughput_type] .. ";")
   end
   print("var bytes = " .. flow["bytes"] .. ";")
   print("var goodput_bytes = " .. flow["goodput_bytes"] .. ";")
end

print [[
 var jitter_in_trend = null;
 var jitter_out_trend = null;
 var packet_lost_in_trend = null;
 var packet_lost_out_trend = null;
 var packet_drop_in_trend = null;
 var packet_drop_out_trend = null;
 var max_delta_time_in_trend = null;
 var max_delta_time_out_trend = null;
 var mos_average_trend = null;
 var r_factor_average_trend = null;
 var mos_in_trend = null;
 var r_factor_in_trend = null;
 var mos_out_trend = null;
 var r_factor_out_trend = null;
 var rtp_rtt_trend = null;
function update () {
	  $.ajax({
		    type: 'GET',
		    url: ']]
print (ntop.getHttpPrefix())
print [[/lua/flow_stats.lua',
		    data: { ifname: "]] print(tostring(ifid)) print [[", flow_key: "]] print(flow_key) print [[" },
		    success: function(content) {
			var rsp = jQuery.parseJSON(content);
			$('#first_seen').html(rsp["seen.first"]);
			$('#last_seen').html(rsp["seen.last"]);
			$('#volume').html(bytesToVolume(rsp.bytes));
			$('#goodput_volume').html(bytesToVolume(rsp["goodput_bytes"]));
			pctg = ((rsp["goodput_bytes"]*100)/rsp["bytes"]).toFixed(1);

			/* 50 is the same threashold specified in FLOW_GOODPUT_THRESHOLD */
			if(pctg < 50) { pctg = "<font color=red>"+pctg+"</font>"; } else if(pctg < 60) { pctg = "<font color=orange>"+pctg+"</font>"; }

			$('#goodput_percentage').html(pctg);
			$('#cli2srv').html(addCommas(rsp["cli2srv.packets"])+" Pkts / "+bytesToVolume(rsp["cli2srv.bytes"]));
			$('#srv2cli').html(addCommas(rsp["srv2cli.packets"])+" Pkts / "+bytesToVolume(rsp["srv2cli.bytes"]));
			$('#throughput').html(rsp.throughput);

			$('#c2sOOO').html(formatPackets(rsp["c2sOOO"]));
			$('#s2cOOO').html(formatPackets(rsp["s2cOOO"]));
			$('#c2slost').html(formatPackets(rsp["c2slost"]));
			$('#s2clost').html(formatPackets(rsp["s2clost"]));
			$('#c2sretr').html(formatPackets(rsp["c2sretr"]));
			$('#s2cretr').html(formatPackets(rsp["s2cretr"]));

			/* **************************************** */

			if(cli2srv_packets == rsp["cli2srv.packets"]) {
			   $('#sent_trend').html("<i class=\"fa fa-minus\"></i>");
			} else {
			   $('#sent_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			}

			if(srv2cli_packets == rsp["srv2cli.packets"]) {
			   $('#rcvd_trend').html("<i class=\"fa fa-minus\"></i>");
			} else {
			   $('#rcvd_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			}

			if(bytes == rsp["bytes"]) {
			   $('#volume_trend').html("<i class=\"fa fa-minus\"></i>");
			} else {
			   $('#volume_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			}

			if(goodput_bytes == rsp["goodput_bytes"]) {
			   $('#goodput_volume_trend').html("<i class=\"fa fa-minus\"></i>");
			} else {
			   $('#goodput_volume_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			}

			if(throughput > rsp["throughput_raw"]) {
			   $('#throughput_trend').html("<i class=\"fa fa-arrow-down\"></i>");
			} else if(throughput < rsp["throughput_raw"]) {
			   $('#throughput_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			   $('#top_throughput').html(rsp["top_throughput_display"]);
			} else {
			   $('#throughput_trend').html("<i class=\"fa fa-minus\"></i>");
			}]]

      if(isThereSIP == 1) then
	updatePrintSip()
      end
      if(isThereRTP == 1) then
	updatePrintRtp()
      end
print [[			cli2srv_packets = rsp["cli2srv.packets"];
			srv2cli_packets = rsp["srv2cli.packets"];
			throughput = rsp["throughput_raw"];
			bytes = rsp["bytes"];

	 /* **************************************** */
	 // Processes information update, based on the pid

	 for (var pid in rsp["processes"]) {
	    var proc = rsp["processes"][pid]
	    // console.log(pid);
	    // console.log(proc);
	    if (proc["memory"])           $('#memory_'+pid).html(proc["memory"]);
	    if (proc["average_cpu_load"]) $('#average_cpu_load_'+pid).html(proc["average_cpu_load"]);
	    if (proc["percentage_iowait_time"]) $('#percentage_iowait_time_'+pid).html(proc["percentage_iowait_time"]);
	    if (proc["page_faults"])      $('#page_faults_'+pid).html(proc["page_faults"]);
	 }

			/* **************************************** */

			var values = thptChart.text().split(",");
			values.shift();
			values.push(rsp.throughput_raw);
			thptChart.text(values.join(",")).change();
		     }
		   });
		 }

]]

print ("setInterval(update,3000);\n")

print [[
</script>
 ]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
