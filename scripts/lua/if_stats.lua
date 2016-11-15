--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
   require "common"
   local json = require "dkjson"
end

require "lua_utils"
require "prefs_utils"
require "graph_utils"
require "alert_utils"
require "db_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

page = _GET["page"]
if_name = _GET["if_name"]
ifid = (_GET["id"] or _GET["ifId"])

msg = ""

function inline_input_form(name, placeholder, tooltip, value, can_edit, input_opts, input_clss)
   print [[
    <form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="id" value="]]
   print(tostring(ifstats.id))
   print('">')

   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

   if(can_edit) then
      print('<input style="width:10em;" title="'..tooltip..'" '..(input_opts or "")..' class="form-control '..(input_clss or "")..'" name="'..name..'" placeholder="'..placeholder..'" value="')
      if(value ~= nil) then print(value) end
      print[["></input>&nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>]]
   else
      if(value ~= nil) then print(value) end
   end
   print("</form>\n")
end

if(_GET["switch_interface"] ~= nil) then
-- First switch interfaces so the new cookie will have effect
ifname = interface.setActiveInterfaceId(tonumber(ifid))

--print("@"..ifname.."="..id.."@")
if((ifname ~= nil) and (_SESSION["session"] ~= nil)) then
   key = getRedisPrefix("ntopng.prefs") .. ".ifname"
   ntop.setCache(key, ifname)

   msg = "<div class=\"alert alert-success\">The selected interface <b>" .. getHumanReadableInterfaceName(ifid)
   msg = msg .. "</b> [id: ".. ifid .."] is now active</div>"

   ntop.setCache(getRedisPrefix("ntopng.prefs")..'.iface', ifid)
else
   msg = "<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Error while switching interfaces</div>"
if(_SESSION["session"] == nil) then
   msg = msg .."<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Empty session</div>"
end
end
end

-- parse interface names and possibly fall back to the selected interface:
-- priority goes to the interface id
if ifid ~= nil and ifid ~= "" then
   if_name = getInterfaceName(ifid)

-- if not interface id is specified we look for the interface name
elseif if_name ~= nil and if_name ~= "" then
   ifid = tostring(interface.name2id(if_name))

-- finally, we fall back to the default selected interface name
else
   -- fall-back to the default interface
   if_name = ifname
   ifid = interface.name2id(ifname)
end

interface.select(if_name)

-- local pcap dump is disabled if the nbox integration is enabled or
-- if the user is not an administrator or if the interface:
-- is a view
-- is not a packet interface (i.e., it is zmq)
is_packetdump_enabled = isLocalPacketdumpEnabled()
is_packet_interface = interface.isPacketInterface()

max_num_shapers = 10

shaper_key = "ntopng.prefs."..ifid..".shaper_max_rate"
ifstats = interface.getStats()

if (isAdministrator()) then
   if(_GET["custom_name"] ~=nil) then
      if(_GET["csrf"] ~= nil) then
	 -- TODO move keys to new schema: replace ifstats.name with ifid
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.name',_GET["custom_name"])
      end
   end

   if(_GET["scaling_factor"] ~= nil) then
      if(_GET["csrf"] ~= nil) then
	 local sf = tonumber(_GET["scaling_factor"])
	 if(sf == nil) then sf = 1 end
	 ntop.setCache(getRedisIfacePrefix(ifid)..'.scaling_factor',tostring(sf))
	 interface.loadScalingFactorPrefs()
      end
   end

   if is_packetdump_enabled then
      if(_GET["dump_all_traffic"] ~= nil and _GET["csrf"] ~= nil) then
	 page = "packetdump"
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_all_traffic',_GET["dump_all_traffic"])
      end
      if(_GET["dump_traffic_to_tap"] ~= nil and _GET["csrf"] ~= nil) then
	 page = "packetdump"
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_tap',_GET["dump_traffic_to_tap"])
      end
      if(_GET["dump_traffic_to_disk"] ~= nil and _GET["csrf"] ~= nil) then
	 page = "packetdump"
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_disk',_GET["dump_traffic_to_disk"])
      end
      if(_GET["dump_unknown_to_disk"] ~= nil and _GET["csrf"] ~= nil) then
	 page = "packetdump"
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_unknown_disk',_GET["dump_unknown_to_disk"])
      end
      if(_GET["dump_security_to_disk"] ~= nil and _GET["csrf"] ~= nil) then
	 page = "packetdump"
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_security_disk',_GET["dump_security_to_disk"])
      end

      if(_GET["sampling_rate"] ~= nil and _GET["csrf"] ~= nil) then
	 if(tonumber(_GET["sampling_rate"]) ~= nil) then
	    page = "packetdump"
	    val = ternary(_GET["sampling_rate"] ~= "0", _GET["sampling_rate"], "1")
	    ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_sampling_rate', val)
	 end
      end
      if(_GET["max_pkts_file"] ~= nil and _GET["csrf"] ~= nil) then
	 if(tonumber(_GET["max_pkts_file"]) ~= nil) then
	    page = "packetdump"
	    ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_pkts_file',_GET["max_pkts_file"])
	 end
      end
      if(_GET["max_sec_file"] ~= nil and _GET["csrf"] ~= nil) then
	 if(tonumber(_GET["max_sec_file"]) ~= nil) then
	    page = "packetdump"
	    ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_sec_file',_GET["max_sec_file"])
	 end
      end
      if(_GET["max_files"] ~= nil and _GET["csrf"] ~= nil) then
	 if(tonumber(_GET["max_files"]) ~= nil) then
	    page = "packetdump"
	    local max_files_size = tonumber(_GET["max_files"])
	    max_files_size = max_files_size * 1000000
	    ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_files', tostring(max_files_size))
	 end
      end
      interface.loadDumpPrefs()
   end
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

print("<link href=\""..ntop.getHttpPrefix().."/css/tablesorted.css\" rel=\"stylesheet\">")
active_page = "if_stats"

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print(msg)

rrdname = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd/bytes.rrd")

url = ntop.getHttpPrefix()..'/lua/if_stats.lua?id=' .. ifid

--  Added global javascript variable, in order to disable the refresh of pie chart in case
--  of historical interface
print('\n<script>var refresh = 3000 /* ms */;</script>\n')

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]

short_name = getHumanReadableInterfaceName(if_name)

if(short_name ~= if_name) then
   short_name = short_name .. "..."
end

print("<li><a href=\"#\">Interface: " .. short_name .."</a></li>\n")

if((page == "overview") or (page == nil)) then
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i></a></li>\n")
else
   print("<li><a href=\""..url.."&page=overview\"><i class=\"fa fa-home fa-lg\"></i></a></li>")
end

-- Disable Packets and Protocols tab in case of the number of packets is equal to 0
if((ifstats ~= nil) and (ifstats.stats.packets > 0)) then
   if(ifstats.type ~= "zmq") then
      if(page == "packets") then
	 print("<li class=\"active\"><a href=\"#\">Packets</a></li>\n")
      else
	 print("<li><a href=\""..url.."&page=packets\">Packets</a></li>")
      end
   end

   if(page == "ndpi") then
      print("<li class=\"active\"><a href=\"#\">Protocols</a></li>\n")
   else
      print("<li><a href=\""..url.."&page=ndpi\">Protocols</a></li>")
   end
end

if(ntop.exists(rrdname) and not is_historical) then
   if(page == "historical") then
      print("<li class=\"active\"><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   else
      print("<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   end
end


if(table.len(ifstats.profiles) > 0) then
  if(page == "trafficprofiles") then
    print("<li class=\"active\"><a href=\""..url.."&page=trafficprofiles\"><i class=\"fa fa-user-md fa-lg\"></i></a></li>")
  else
    print("<li><a href=\""..url.."&page=trafficprofiles\"><i class=\"fa fa-user-md fa-lg\"></i></a></li>")
  end
end

if is_packetdump_enabled then
   if(page == "packetdump") then
      print("<li class=\"active\"><a href=\""..url.."&page=packetdump\"><i class=\"fa fa-hdd-o fa-lg\"></i></a></li>")
   else
      print("<li><a href=\""..url.."&page=packetdump\"><i class=\"fa fa-hdd-o fa-lg\"></i></a></li>")
   end
end

if(isAdministrator()) then
   if(page == "alerts") then
      print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-warning fa-lg\"></i></a></li>\n")
   elseif interface.isPcapDumpInterface() == false then
      print("\n<li><a href=\""..url.."&page=alerts\"><i class=\"fa fa-warning fa-lg\"></i></a></li>")
   end
end

if ntop.isEnterprise() then
    if(page == "report") then
        print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-file-text fa-lg\"></i></a></li>\n")
    else
        print("\n<li><a href=\""..url.."&page=report\"><i class=\"fa fa-file-text fa-lg\"></i></a></li>")
    end
end

if(isAdministrator()) then
   if(page == "config") then
      print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-cog fa-lg\"></i></a></li>\n")
   elseif interface.isPcapDumpInterface() == false then
      print("\n<li><a href=\""..url.."&page=config\"><i class=\"fa fa-cog fa-lg\"></i></a></li>")
   end
end

if(ifstats.inline) then
   if(page == "filtering") then
      print("<li class=\"active\"><a href=\""..url.."&page=filtering\">Traffic Filtering</a></li>")
   else
      print("<li><a href=\""..url.."&page=filtering\">Traffic Filtering</a></li>")
   end

   if(page == "shaping") then
      print("<li class=\"active\"><a href=\""..url.."&page=shaping\">Traffic Shaping</a></li>")
   else
      print("<li><a href=\""..url.."&page=shaping\">Traffic Shaping</a></li>")
   end
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
   ]]

if((page == "overview") or (page == nil)) then
   print("<table class=\"table table-striped table-bordered\">\n")
   print("<tr><th width=15%>Id</th><td colspan=6>" .. ifstats.id .. " ")
   print("</td></tr>\n")

   if interface.isPcapDumpInterface() == false then
      print("<tr><th width=250>State</th><td colspan=6>")
      state = toggleTableButton("", "", "Active", "1","primary", "Paused", "0","primary", "toggle_local", "ntopng.prefs."..if_name.."_not_idle")

      if(state == "0") then
	 on_state = true
      else
	 on_state = false
      end

      interface.setInterfaceIdleState(on_state)
      print("</td></tr>\n")
   end

   if(ifstats["remote.name"] ~= nil) then
      print("<tr><th>Remote Probe</th><td nowrap><b>Interface Name</b>: "..ifstats["remote.name"].." [ ".. maxRateToString(ifstats.speed*1000) .." ]</td>")
      if(ifstats["remote.if_addr"] ~= "") then print("<td nowrap><b>Interface IP</b>: "..ifstats["remote.if_addr"].."</td>") end
      if(ifstats["probe.ip"] ~= "") then print("<td nowrap><b>Probe IP</b>: "..ifstats["probe.ip"].."</td><td></td>") end
      if(ifstats["probe.public_ip"] ~= "") then
	 print("<td nowrap><b>Public Probe IP</b>: <A HREF=http://"..ifstats["probe.public_ip"]..">"..ifstats["probe.public_ip"].."</A> <i class='fa fa-external-link'></i></td>\n")
      else
	 print("<td>&nbsp;</td>\n")
      end
      print("</tr>\n")
   end

   local is_physical_iface = (interface.isPacketInterface()) and (interface.isPcapDumpInterface() == false)

   if not interface.isBridgeInterface() then
      print('<tr><th width="250">Name</th><td colspan="2">' .. ifstats.name..'</td>\n')

      if is_physical_iface then
	 if(ifstats.name ~= nil) then
	    print('<th>Custom Name</th><td colspan="3">')
	    label = getInterfaceNameAlias(ifstats.name)
	    inline_input_form("custom_name", "Custom Name",
		"Specify an alias for the interface",
		label, isAdministrator(), 'autocorrect="off" spellcheck="false" pattern="^[_\\-a-zA-Z0-9]*$"')
	    print("</td></tr>\n")
	 end
      
	 local speed_key = 'ntopng.prefs.'..ifname..'.speed'
	 local speed = ntop.getCache(speed_key)
	 if speed == nil or speed == "" or tonumber(speed) == nil then
	    speed = ifstats.speed
	 end
	 print("<tr><th width=250>Speed</th><td colspan=2>" .. maxRateToString(speed*1000) .. "</td>")

	 if interface.isPacketInterface() then
	    print("</td><th>Scaling Factor</th><td colspan=3>")
	    local label = ntop.getCache(getRedisIfacePrefix(ifid)..".scaling_factor")
	    if((label == nil) or (label == "")) then label = "1" end
	    inline_input_form("scaling_factor", "Scaling Factor",
	       "This should match your capture interface sampling rate",
	       label, isAdministrator(), 'type="number" min="1" step="1"', 'no-spinner')
	 end

	 print("</td></tr>\n")
      else
	 print("<td colspan=4></td>")
      end
   else
      print("<tr><th>Bridge</th><td colspan=7>"..ifstats["bridge.device_a"].." <i class=\"fa fa-arrows-h\"> "..ifstats["bridge.device_b"].."</td></tr>")
   end

   if(ifstats.ip_addresses ~= "") then
      tokens = split(ifstats.ip_addresses, ",")

      if(tokens ~= nil) then
	 print("<tr><th width=250>IP Address</th><td colspan=5>")

	 for _,s in pairs(tokens) do
	    t = string.split(s, "/")
	    host = interface.getHostInfo(t[1])

	    if(host ~= nil) then
	       print("<li><A HREF="..ntop.getHttpPrefix().."/lua/host_details.lua?host="..t[1]..">".. t[1].."</A>\n")
	    else
	       print("<li>".. t[1].."\n")
	    end
	 end

	 print("</td></tr>")
      end
   end

   print("<tr><th>Family </th><td colspan=2>")

   print(ifstats.type)
   if(ifstats.inline) then
      print(" In-Path Interface (Bump in the Wire)")
   end

   if is_physical_iface then
      print("<th>MTU</th><td colspan=3  nowrap>"..ifstats.mtu.." bytes</td></tr>\n")
   else
      print("<td colspan=4></td>")
   end

   if(ifstats["pkt_dumper"] ~= nil) then
      print("<tr><th rowspan=2>Packet Dumper</th><th colspan=2>Dumped Packets</th><th colspan=2>Dumped Files</th></tr>\n")
      print("<tr><td colspan=2><div id=dumped_pkts>".. formatValue(ifstats["pkt_dumper"]["num_dumped_pkts"]) .."</div></td>")
      print("<td colspan=2><div id=dumped_files>".. formatValue(ifstats["pkt_dumper"]["num_dumped_files"]) .."</div></td></tr>\n")
   end

   label = "Pkts"

   print[[ <tr><th colspan=1 nowrap>Traffic Breakdown</th> ]]

   if(ifstats.type ~= "zmq") then
      print [[ <td colspan=2><div class="pie-chart" id="ifaceTrafficBreakdown"></div></td><td colspan=3> <div class="pie-chart" id="ifaceTrafficDistribution"></div></td></tr> ]]
   else
      print [[ <td colspan=4><div class="pie-chart" id="ifaceTrafficBreakdown"></div></td></tr> ]]
   end

print [[
	<script type='text/javascript'>
	       window.onload=function() {
				   do_pie("#ifaceTrafficBreakdown", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_local_stats.lua', { id: ]] print(ifstats.id .. " }, \"\", refresh); \n")

if(ifstats.type ~= "zmq") then
print [[				   do_pie("#ifaceTrafficDistribution", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_local_stats.lua', { id: ]] print(ifstats.id .. ", mode: \"distribution\" }, \"\", refresh); \n")
end
print [[ }

]]
print("</script>\n")

   if(ifstats.zmqRecvStats ~= nil) then
   print("<tr><th colspan=7 nowrap>ZMQ RX Statistics</th></tr>\n")
   print("<tr><th nowrap>Collected Flows</th><td width=20%><span id=if_zmq_flows>"..formatValue(ifstats.zmqRecvStats.flows).."</span>")
   print("<th nowrap>Interface RX Updates</th><td width=20%><span id=if_zmq_events>"..formatValue(ifstats.zmqRecvStats.events).."</span>")
   print("<th nowrap>sFlow Counter Updates</th><td width=20%><span id=if_zmq_counters>"..formatValue(ifstats.zmqRecvStats.counters).."</span></tr>")
   end

   print("<tr><th colspan=7 nowrap>Ingress Traffic</th></tr>\n")
   print("<tr><th nowrap>Received Traffic</th><td width=20%><span id=if_bytes>"..bytesToSize(ifstats.stats.bytes).."</span> [<span id=if_pkts>".. formatValue(ifstats.stats.packets) .. " ".. label .."</span>] ")
   print("<span id=pkts_trend></span></td><th width=20%>Dropped Packets</th><td width=20%><span id=if_drops>")

   if(ifstats.stats.drops > 0) then print('<span class="label label-danger">') end
   print(formatValue(ifstats.stats.drops).. " " .. label)

   if((ifstats.stats.packets+ifstats.stats.drops) > 0) then
      local pctg = round((ifstats.stats.drops*100)/(ifstats.stats.packets+ifstats.stats.drops), 2)
      if(pctg > 0) then print(" [ " .. pctg .. " % ] ") end
   end

   if(ifstats.stats.drops > 0) then print('</span>') end
   print("</span>  <span id=drops_trend></span></td><td colspan=3>&nbsp;</td></tr>\n")

   if(prefs.is_dump_flows_enabled) then
      local dump_to = "MySQL"
      if prefs.is_dump_flows_to_es_enabled == true then
	 dump_to = "ElasticSearch"
      end

      local export_count     = ifstats.stats.flow_export_count
      local export_rate      = ifstats.stats.flow_export_rate
      local export_drops     = ifstats.stats.flow_export_drops
      local export_drops_pct = 0
      if export_drops > 0 and export_count > 0 then
	 export_drops_pct = export_drops / export_count * 100
      end

      print("<tr><th colspan=7 nowrap>"..dump_to.." Flows Export Statistics</th></tr>\n")

      print("<tr>")
      print("<th nowrap>Exported Flows</th>")
      print("<td><span id=exported_flows>"..formatValue(export_count).."</span>")
      print("&nbsp;[<span id=exported_flows_rate>"..formatValue(round(export_rate, 2)).."</span> Flows/s]</td>")
      print("<th>Dropped Flows</th>")
      local span_danger = ""
      if(export_drops > 0) then
	 span_danger = ' class="label label-danger"'
      end
      print("<td><span id=exported_flows_drops "..span_danger..">"..formatValue(export_drops).."</span>&nbsp;")
      print("<span id=exported_flows_drops_pct "..span_danger..">["
	       ..formatValue(round(export_drops_pct, 2)).."%]</span></td>")
      print("<td colspan=3>&nbsp;</td>")
      print("</tr>")

   end

   if(interface.isBridgeInterface()) then
      print("<tr><th colspan=7>Bridged Traffic</th></tr>\n")
      print("<tr><th nowrap>Interface Direction</th><th nowrap>Ingress Packets</th><th nowrap>Egress Packets</th><th nowrap>Shaped Packets</th><th nowrap>Filtered Packets</th><th nowrap>Send Error</th><th nowrap>Buffer Full</th></tr>\n")
      print("<tr><th>".. ifstats["bridge.device_a"] .. " <i class=\"fa fa-arrow-right\"></i> ".. ifstats["bridge.device_b"] .."</th><td><span id=a_to_b_in_pkts>".. formatPackets(ifstats["bridge.a_to_b.in_pkts"]) .."</span> <span id=a_to_b_in_pps></span></td>")
      print("<td><span id=a_to_b_out_pkts>".. formatPackets(ifstats["bridge.a_to_b.out_pkts"]) .."</span> <span id=a_to_b_out_pps></span></td>")
      print("<td><span id=a_to_b_shaped_pkts>".. formatPackets(ifstats["bridge.a_to_b.shaped_pkts"]) .."</span></td>")
      print("<td><span id=a_to_b_filtered_pkts>".. formatPackets(ifstats["bridge.a_to_b.filtered_pkts"]) .."</span></td>")

      print("<td><span id=a_to_b_num_pkts_send_error>".. formatPackets(ifstats["bridge.a_to_b.num_pkts_send_error"]) .."</span></td>")
      print("<td><span id=a_to_b_num_pkts_send_buffer_full>".. formatPackets(ifstats["bridge.a_to_b.num_pkts_send_buffer_full"]) .."</span></td>")

      print("</tr>\n")

      print("<tr><th>".. ifstats["bridge.device_b"] .. " <i class=\"fa fa-arrow-right\"></i> ".. ifstats["bridge.device_a"] .."</th><td><span id=b_to_a_in_pkts>".. formatPackets(ifstats["bridge.b_to_a.in_pkts"]) .."</span> <span id=b_to_a_in_pps></span></td>")
      print("<td><span id=b_to_a_out_pkts>"..formatPackets( ifstats["bridge.b_to_a.out_pkts"]) .."</span> <span id=b_to_a_out_pps></span></td>")
      print("<td><span id=b_to_a_shaped_pkts>".. formatPackets(ifstats["bridge.b_to_a.shaped_pkts"]) .."</span></td>")
      print("<td><span id=b_to_a_filtered_pkts>".. formatPackets(ifstats["bridge.b_to_a.filtered_pkts"]) .."</span></td>")

      print("<td><span id=b_to_a_num_pkts_send_error>".. formatPackets(ifstats["bridge.b_to_a.num_pkts_send_error"]) .."</span></td>")
      print("<td><span id=b_to_a_num_pkts_send_buffer_full>".. formatPackets(ifstats["bridge.b_to_a.num_pkts_send_buffer_full"]) .."</span></td>")

      print("</tr>\n")
   end

   print [[
   <tr><td colspan=7> <small> <b>NOTE</b>:<p>In ethernet networks, each packet has an <A HREF=https://en.wikipedia.org/wiki/Ethernet_frame>overhead of 24 bytes</A> [preamble (7 bytes), start of frame (1 byte), CRC (4 bytes), and <A HREF=http://en.wikipedia.org/wiki/Interframe_gap>IFG</A> (12 bytes)]. Such overhead needs to be accounted to the interface traffic, but it is not added to the traffic being exchanged between IP addresses. This is because such data contributes to interface load, but it cannot be accounted in the traffic being exchanged by hosts, and thus expect little discrepancies between host and interface traffic values. </small> </td></tr>
   ]]

   print("</table>\n")
elseif((page == "packets")) then
   print [[ <table class="table table-bordered table-striped"> ]]
      print("<tr><th width=30% rowspan=3>TCP Packets Analysis</th><th>Retransmissions</th><td align=right><span id=pkt_retransmissions>".. formatPackets(ifstats.tcpPacketStats.retransmissions) .."</span> <span id=pkt_retransmissions_trend></span></td></tr>\n")
      print("<tr></th><th>Out of Order</th><td align=right><span id=pkt_ooo>".. formatPackets(ifstats.tcpPacketStats.out_of_order) .."</span> <span id=pkt_ooo_trend></span></td></tr>\n")
      print("<tr></th><th>Lost</th><td align=right><span id=pkt_lost>".. formatPackets(ifstats.tcpPacketStats.lost) .."</span> <span id=pkt_lost_trend></span></td></tr>\n")

    print [[
	<tr><th class="text-left">Size Distribution</th><td colspan=5><div class="pie-chart" id="sizeDistro"></div></td></tr>
      </table>

	<script type='text/javascript'>
	 window.onload=function() {

       do_pie("#sizeDistro", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/if_pkt_distro.lua', { distr: "size", ifname: "]] print(if_name.."\"")
   print [[
	   }, "", refresh);
    }

      </script><p>
  ]]
elseif(page == "ndpi") then

--fc = interface.getnDPIFlowsCount()
--for k,v in pairs(fc) do
--   io.write(k.."="..v.."\n")
--end

   print [[
	    <script type="text/javascript" src="]] print(ntop.getHttpPrefix()) print [[/js/jquery.tablesorter.js"></script>
      <table class="table table-bordered table-striped">
      <tr><th class="text-left">Cumulative Protocol Stats</th>
	       <td colspan=3><div class="pie-chart" id="topApplicationProtocols"></div></td>
	       <td colspan=2><div class="pie-chart" id="topApplicationBreeds"></div></td>
	       </tr>
      <tr><th class="text-left">Live Flows Count</th>
	       <td colspan=3><div class="pie-chart" id="topFlowsCount"></div></td>
	       <td colspan=2><div class="pie-chart" id="topTCPFlowsStats"></div>
               <br><small><b>NOTE:</b> This chart depicts only TCP connections.
               </td>
	       </tr>
  </div>

	<script type='text/javascript'>
	 window.onload=function() {

       do_pie("#topApplicationProtocols", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_ndpi_stats.lua', { mode: "sinceStartup", id: "]] print(ifid) print [[" }, "", refresh);

       do_pie("#topApplicationBreeds", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_ndpi_stats.lua', { breed: "true", mode: "sinceStartup", id: "]] print(ifid) print [[" }, "", refresh);

       do_pie("#topFlowsCount", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_ndpi_stats.lua', { breed: "true", mode: "count", id: "]] print(ifid) print [[" }, "", refresh);

       do_pie("#topTCPFlowsStats", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_tcp_stats.lua', { id: "]] print(ifid) print [[" }, "", refresh);
    }

      </script><p>
  </table>
  ]]

   print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     ]]

   print("<thead><tr><th>Application Protocol</th><th>Total (Since Startup)</th><th>Percentage</th></tr></thead>\n")

   print ('<tbody id="if_stats_ndpi_tbody">\n')
   print ("</tbody>")
   print("</table>\n")
   print [[
<script>
function update_ndpi_table() {
  $.ajax({
    type: 'GET',
    url: ']]
   print (ntop.getHttpPrefix())
   print [[/lua/if_stats_ndpi.lua',
    data: { id: "]] print(ifid) print [[" },
    success: function(content) {
      $('#if_stats_ndpi_tbody').html(content);
      // Let the TableSorter plugin know that we updated the table
      $('#if_stats_ndpi_tbody').trigger("update");
    }
  });
}
update_ndpi_table();
]]

--  Update interval ndpi table
print("setInterval(update_ndpi_table, 5000);")

   print [[

</script>

]]

elseif(page == "historical") then
   rrd_file = _GET["rrd_file"]
   selected_epoch = _GET["epoch"]
   if(selected_epoch == nil) then selected_epoch = "" end
   topArray = makeTopStatsScriptsArray()

   if(rrd_file == nil) then rrd_file = "bytes.rrd" end
   drawRRD(ifstats.id, nil, rrd_file, _GET["graph_zoom"], url.."&page=historical", 1, _GET["epoch"], selected_epoch, topArray)
   --drawRRD(ifstats.id, nil, rrd_file, _GET["graph_zoom"], url.."&page=historical", 1, _GET["epoch"], selected_epoch, topArray, _GET["comparison_period"])
elseif(page == "trafficprofiles") then
   print("<table class=\"table table-striped table-bordered\">\n")
   print("<tr><th width=15%><a href=\""..ntop.getHttpPrefix().."/lua/pro/admin/edit_profiles.lua\">Profile Name</A></th><th width=5%>Chart</th><th>Traffic</th></tr>\n")
   for pname,pbytes in pairs(ifstats.profiles) do
     local trimmed = trimSpace(pname)
     local rrdname = fixPath(dirs.workingdir .. "/" .. ifid .. "/profilestats/" .. getPathFromKey(trimmed) .. "/bytes.rrd")
     local statschart_icon = ''
     if ntop.exists(rrdname) then
	 statschart_icon = '<A HREF='..ntop.getHttpPrefix()..'/lua/profile_details.lua?profile='..trimmed..'><i class=\'fa fa-area-chart fa-lg\'></i></A>'
     end

     print("<tr><th>"..pname.."</th><td align=center>"..statschart_icon.."</td><td><span id=profile_"..trimmed..">"..bytesToSize(pbytes).."</span> <span id=profile_"..trimmed.."_trend></span></td></tr>\n")
   end

print [[
   </table>

   <script>
   var last_profile = [];
   var traffic_profiles_interval = window.setInterval(function() {
	  $.ajax({
		    type: 'GET',
		    url: ']]
   print (ntop.getHttpPrefix())
   print [[/lua/network_load.lua',
		    data: { ifname: "]] print(if_name) print [[" },
		    success: function(content) {
			var profiles = content;

			if(profiles["profiles"] != null) {
			   for (key in profiles["profiles"]) {
			     k = '#profile_'+key.replace(" ", "");
			     v = profiles["profiles"][key];
			     $(k).html(bytesToVolume(v));
			     k += "_trend";
			     last = last_profile[key];
			     if(last == null) { last = 0; }
			     $(k).html(get_trend(last, v));
			   }

			   last_profile = profiles["profiles"];
			  }
			}
	  });
}, 3000);

   </script>
]]
elseif(page == "packetdump") then

if is_packetdump_enabled then
  dump_all_traffic = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_all_traffic')
  dump_status_tap = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_tap')
  dump_status_disk = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_disk')
  dump_unknown_disk = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_unknown_disk')
  dump_security_disk = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_security_disk')

  if(dump_all_traffic == "true") then
    dump_all_traffic_checked = 'checked="checked"'
    dump_all_traffic_value = "false" -- Opposite
  else
    dump_all_traffic_checked = ""
    dump_all_traffic_value = "true" -- Opposite
  end
  if(dump_status_disk == "true") then
    dump_traffic_checked = 'checked="checked"'
    dump_traffic_value = "false" -- Opposite
  else
    dump_traffic_checked = ""
    dump_traffic_value = "true" -- Opposite
  end
  if(dump_unknown_disk == "true") then
    dump_unknown_checked = 'checked="checked"'
    dump_unknown_value = "false" -- Opposite
  else
    dump_unknown_checked = ""
    dump_unknown_value = "true" -- Opposite
  end
  if(dump_security_disk == "true") then
    dump_security_checked = 'checked="checked"'
    dump_security_value = "false" -- Opposite
  else
    dump_security_checked = ""
    dump_security_value = "true" -- Opposite
  end
  if(dump_status_tap == "true") then
    dump_traffic_tap_checked = 'checked="checked"'
    dump_traffic_tap_value = "false" -- Opposite
  else
    dump_traffic_tap_checked = ""
    dump_traffic_tap_value = "true" -- Opposite
  end

   print("<table class=\"table table-striped table-bordered\">\n")

   print("<tr><th width=30%>Packet Dump</th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
	 <input type="hidden" name="ifId" value="]]
	       print(ifid)
	       print('"><input type="hidden" name="dump_all_traffic" value="'..dump_all_traffic_value..'"><input type="checkbox" value="1" '..dump_all_traffic_checked..' onclick="this.form.submit();">  Dump All Traffic')
	       print('</input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%>Packet Dump To Disk</th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
	 <input type="hidden" name="ifId" value="]]
	       print(ifid)
	       print('"><input type="hidden" name="dump_traffic_to_disk" value="'..dump_traffic_value..'"><input type="checkbox" value="1" '..dump_traffic_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> Dump Traffic To Disk')
	       if(dump_traffic_checked ~= "") then
		 dumped = interface.getInterfacePacketsDumpedFile()
		 print(" - "..ternary(dumped, dumped, 0).." packets dumped")
	       end
	       print('</input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%></th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
	 <input type="hidden" name="ifId" value="]]
	       print(ifid)
	       print('"><input type="hidden" name="dump_unknown_to_disk" value="'..dump_unknown_value..'"><input type="checkbox" value="1" '..dump_unknown_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> Dump Unknown Traffic To Disk </input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%></th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
	 <input type="hidden" name="ifId" value="]]
	       print(ifid)
	       print('"><input type="hidden" name="dump_security_to_disk" value="'..dump_security_value..'"><input type="checkbox" value="1" '..dump_security_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> Dump Traffic To Disk On Security Alert </input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th>Packet Dump To Tap</th><td>")
   if(interface.getInterfaceDumpTapName() ~= "") then
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
	 <input type="hidden" name="ifId" value="]]
	       print(ifId)
	       print('"><input type="hidden" name="dump_traffic_to_tap" value="'..dump_traffic_tap_value..'"><input type="checkbox" value="1" '..dump_traffic_tap_checked..' onclick="this.form.submit();"> <i class="fa fa-filter fa-lg"></i> Dump Traffic To Tap ')
	       print('('..interface.getInterfaceDumpTapName()..')')
	       if(dump_traffic_tap_checked ~= "") then
		 dumped = interface.getInterfacePacketsDumpedTap()
		 print(" - "..ternary(dumped, dumped, 0).." packets dumped")
	       end
	       print(' </input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   else
      print("Disabled. Please restart ntopng with --enable-taps")
end

   print("</td></tr>\n")
   print("<tr><th width=250>Sampling Rate</th>\n")
   print [[<td>]]
   if(dump_security_checked ~= "") then
   print[[<form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="ifId" value="]]
      print(ifId)
      print [[">]]
      print('1 : <input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="sampling_rate" placeholder="" min="0" step="100" max="100000" value="]]
	 srate = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_sampling_rate')
	 if(srate ~= nil and srate ~= "" and srate ~= "0") then print(srate) else print("1000") end
	 print [["></input>
      &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
<small>
    NOTE: Sampling rate is applied only when dumping packets caused by a security alert<br>
(e.g. a volumetric DDoS attack) and not to those hosts/flows that have been marked explicitly for dump.
</small>]]
  else
    print('Disabled. Enable packet dump on security alert.')
  end
  print[[
    </td></tr>
       ]]

   print("<tr><th colspan=2>Dump To Disk Parameters</th></tr>")
   print("<tr><th width=250>Pcap Dump Directory</th><td>")
   pcapdir = dirs.workingdir .."/"..ifstats.id.."/pcap/"
   print(pcapdir.."</td></tr>\n")
   print("<tr><th width=250>Max Packets per File</th>\n")
   print [[<td>
    <form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="ifid" value="]]
      print(ifid)
      print [[">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="max_pkts_file" placeholder="" min="0" step="1000" max="100000" value="]]
	 max_pkts_file = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_max_pkts_file')
	 if(max_pkts_file ~= nil and max_pkts_file ~= "") then
	   print(max_pkts_file.."")
	 else
	   print(interface.getInterfaceDumpMaxPkts().."")
	 end
	 print [["></input> pkts &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
    <small>Maximum number of packets to store on a pcap file before creating a new file.</small>
    </td></tr>
       ]]
   print("<tr><th width=250>Max Duration of File</th>\n")
   print [[<td>
    <form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="ifId" value="]]
      print(ifid)
      print [[">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="max_sec_file" placeholder="" min="0" step="60" max="100000" value="]]
	 max_sec_file = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_max_sec_file')
	 if(max_sec_file ~= nil and max_sec_file ~= "") then
	   print(max_sec_file.."")
	 else
	   print(interface.getInterfaceDumpMaxSec().."")
	 end
	 print [["></input>
		  &nbsp;sec &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
    <small>Maximum pcap file duration before creating a new file.<br>NOTE: a dump file is closed when it reaches first the maximum size or duration specified.</small>
    </td></tr>
       ]]
   print("<tr><th width=250>Max Size of Dump Files</th>\n")
   print [[<td>
    <form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="ifid" value="]]
      print(ifid)
      print [[">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="max_files" placeholder="" min="0" step="1" max="100000000" value="]]
	 max_files = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_max_files')
	 if(max_files ~= nil and max_files ~= "") then
	   print(tostring(tonumber(max_files)/1000000).."")
	 else
	   print(tostring(tonumber(interface.getInterfaceDumpMaxFiles())/1000000).."")
	 end
	 print [["></input>
		  &nbsp; MB &nbsp;&nbsp;&nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
    <small>Maximum size of created pcap files.<br>NOTE: total file size is checked daily and old dump files are automatically overwritten after reaching the threshold.</small>
    </td></tr>
      ]]
   print("</table>")
end
elseif(page == "alerts") then
local ifname_clean = "iface_"..tostring(ifid)
local tab = _GET["tab"]
local re_arm_minutes = nil

if(tab == nil) then tab = alerts_granularity[1][1] end

print [[ <ul class="nav nav-tabs">
]]

for _,e in pairs(alerts_granularity) do
   local k = e[1]
   local l = e[2]
   l = '<i class="fa fa-wrench" aria-hidden="true"></i>&nbsp;'..l

   if(k == tab) then print("\t<li class=active>") else print("\t<li>") end
   print("<a href=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?id="..ifid.."&page=alerts&tab="..k.."\">"..l.."</a></li>\n")
end

-- Before doing anything we need to check if we need to save values

vals = { }
alerts = ""
to_save = false

if((_GET["to_delete"] ~= nil) and (_GET["SaveAlerts"] == nil)) then
   delete_alert_configuration(ifname_clean, ifname)
   alerts = nil
else
   for k,_ in pairs(alert_functions_description) do
      value    = _GET["value_"..k]
      operator = _GET["operator_"..k]

      if((value ~= nil) and (operator ~= nil)) then
	 --io.write("\t"..k.."\n")
	 to_save = true
	 value = tonumber(value)
	 if(value ~= nil) then
	   if(alerts ~= "") then alerts = alerts .. "," end
	   alerts = alerts .. k .. ";" .. operator .. ";" .. value
	 else
	   if ntop.isPro() then ntop.withdrawNagiosAlert(ifname_clean, tab, k, "alarm not installed") end
	 end
      end
   end

   --print(alerts)

   if(to_save) then
      refresh_alert_configuration(ifname_clean, ifname, tab, alerts)
      if(alerts == "") then
	 ntop.delHashCache(get_alerts_hash_name(tab, ifname), ifname_clean)
      else
	 ntop.setHashCache(get_alerts_hash_name(tab, ifname), ifname_clean, alerts)
      end
   else
      alerts = ntop.getHashCache(get_alerts_hash_name(tab, ifname), ifname_clean)
   end
   if _GET["re_arm_minutes"] then
      ntop.setHashCache(get_re_arm_alerts_hash_name(tab),
			"ifid_"..tostring(ifId).."_"..ifname_clean,
			_GET["re_arm_minutes"])
   end
   re_arm_minutes = ntop.getHashCache(get_re_arm_alerts_hash_name(tab),
				      "ifid_"..tostring(ifId).."_"..ifname_clean)
   if not re_arm_minutes then re_arm_minutes="" end
end

if(alerts ~= nil) then
   --print(alerts)
   --tokens = string.split(alerts, ",")
   tokens = split(alerts, ",")

   --print(tokens)
   if(tokens ~= nil) then
      for _,s in pairs(tokens) do
	 t = string.split(s, ";")
	 --print("-"..t[1].."-")
	 if(t ~= nil) then vals[t[1]] = { t[2], t[3] } end
      end
   end
end

if(tab == "alerts_preferences") then
   suppressAlerts = ntop.getHashCache(get_alerts_suppressed_hash_name(ifname), "iface_"..tostring(ifid))
   if((suppressAlerts == "") or (suppressAlerts == nil) or (suppressAlerts == "true")) then
      alerts_checked = 'checked="checked"'
      alerts_value = "false" -- Opposite
   else
      alerts_checked = ""
      alerts_value = "true" -- Opposite
   end

else
   print [[
    </ul>
    <table id="user" class="table table-bordered table-striped" style="clear: both"> <tbody>
    <tr><th width=20%>Alert Function</th><th>Threshold</th></tr>


   <form>
    <input type=hidden name=page value=alerts>
   ]]

   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
   print("<input type=hidden name=ifId value=\""..ifid.."\">\n")
   print("<input type=hidden name=tab value="..tab..">\n")

   for k,v in pairsByKeys(alert_functions_description, asc) do
      print("<tr><th>"..k.."</th><td>\n")
      print("<select name=operator_".. k ..">\n")
      if((vals[k] ~= nil) and (vals[k][1] == "gt")) then print("<option selected=\"selected\"") else print("<option ") end
      print("value=\"gt\">&gt;</option>\n")

      if((vals[k] ~= nil) and (vals[k][1] == "eq")) then print("<option selected=\"selected\"") else print("<option ") end
      print("value=\"eq\">=</option>\n")

      if((vals[k] ~= nil) and (vals[k][1] == "lt")) then print("<option selected=\"selected\"") else print("<option ") end
      print("value=\"lt\">&lt;</option>\n")
      print("</select>\n")
      print("<input type=text name=\"value_"..k.."\" value=\"")
      if(vals[k] ~= nil) then print(vals[k][2]) end
      print("\">\n\n")
      print("<br><small>"..v.."</small>\n")
      print("</td></tr>\n")
   end

   print [[
   <tr><td colspan=2  style="text-align: left; white-space: nowrap;" ></td></tr>
   <tr>
     <td style="text-align: left; white-space: nowrap;" ><b>Re-arm minutes</b></td>
     <td>
     <input type="number" name="re_arm_minutes" style="width: 50px;" value=]] print(tostring(re_arm_minutes)) print[[><br>
     <small>The re-arm is the dead time between one alert generation and the potential generation of the next alert of the same kind. </small>
     </td>
   </tr>

   <tr><th colspan=2  style="text-align: center; white-space: nowrap;" >

   <input type="submit" class="btn btn-primary" name="SaveAlerts" value="Save Configuration">

   <a href="#myModal" role="button" class="btn" data-toggle="modal">[ <i type="submit" class="fa fa-trash-o"></i> Delete All Interface Configured Alerts ]</button></a>
   <!-- Modal -->
   <div class="modal fade" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">
     <div class="modal-dialog">
       <div class="modal-content">
	 <div class="modal-header">
       <button type="button" class="close" data-dismiss="modal" aria-hidden="true">X</button>
       <h3 id="myModalLabel">Confirm Action</h3>
     </div>
     <div class="modal-body">
	 <p>Do you really want to delete all configured alerts for interface ]] print(if_name) print [[?</p>
     </div>
     <div class="modal-footer">
       <form class=form-inline style="margin-bottom: 0px;" method=get action="#"><input type=hidden name=to_delete value="__all__">
   ]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
   print [[    <button class="btn btn-default" data-dismiss="modal" aria-hidden="true">Close</button>
       <button class="btn btn-primary" type="submit">Delete All</button>

     </div>
   </form>
   </div>
   </div>

   </th> </tr>



   </tbody> </table>
   ]]
end
elseif(page == "config") then
local if_name = ifstats.name
local ifname_clean = "iface_"..tostring(ifid)

   if(isAdministrator()) then
      trigger_alerts = _GET["trigger_alerts"]
      if(trigger_alerts ~= nil) then
	 if(trigger_alerts == "true") then
	    ntop.delHashCache(get_alerts_suppressed_hash_name(ifname), ifname_clean)
	 else
	    ntop.setHashCache(get_alerts_suppressed_hash_name(ifname), ifname_clean, trigger_alerts)
	 end
      end
   end

   print("<table class=\"table table-striped table-bordered\">\n")
       suppressAlerts = ntop.getHashCache(get_alerts_suppressed_hash_name(ifname), ifname_clean)
       if((suppressAlerts == "") or (suppressAlerts == nil) or (suppressAlerts == "true")) then
	  alerts_checked = 'checked="checked"'
	  alerts_value = "false" -- Opposite
       else
	  alerts_checked = ""
	  alerts_value = "true" -- Opposite
       end

       print [[
	    <tr><th>Interface Alerts</th><td nowrap>
	    <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
	    <input type="hidden" name="tab" value="alerts_preferences">
	    <input type="hidden" name="ifId" value="]]

	 print(ifid)
	 print('"><input type="hidden" name="trigger_alerts" value="'..alerts_value..'"><input type="checkbox" value="1" '..alerts_checked..' onclick="this.form.submit();"> <i class="fa fa-exclamation-triangle fa-lg"></i> Trigger alerts for interface '..if_name..'</input>')
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	 print('<input type="hidden" name="page" value="config">')
	 print('</form>')
	 print('</td>')
	 print [[</tr>]]

    print("</table>")
elseif(page == "shaping") then
shaper_id = _GET["shaper_id"]
max_rate = _GET["max_rate"]

if((shaper_id ~= nil) and (max_rate ~= nil)) then
   shaper_id = tonumber(shaper_id)
   max_rate = tonumber(max_rate)
   if((shaper_id >= 0) and (shaper_id < max_num_shapers)) then
      if(max_rate > 1048576) then max_rate = -1 end
      if(max_rate < -1) then max_rate = -1 end
      ntop.setHashCache(shaper_key, shaper_id, max_rate.."")
      interface.reloadShapers()
   end
end

print [[
<table class="table table-striped table-bordered">
 <tr><th width=10%>Shaper Id</th><th>Max Rate</th></tr>
]]


for i=0,max_num_shapers-1 do
   max_rate = ntop.getHashCache(shaper_key, i)
   if(max_rate == "") then max_rate = -1 end
   print('<tr><th style=\"text-align: center;\">'..i)

   print [[
	 </th><td><form class="form-inline" style="margin-bottom: 0px;">
	 <input type="hidden" name="page" value="shaping">
	 <input type="hidden" name="if_name" value="]] print(if_name) print[[">
	 <input type="hidden" name="shaper_id" value="]] print(i.."") print [[">]]

      if(isAdministrator()) then
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

	 print('<input class=form-control type="number" name="max_rate" placeholder="" min="-1" value="'.. max_rate ..'">&nbsp;Kbps')
	 print('&nbsp;<button type="submit" style="margin-top: 0; height: 26px" class="btn btn-default btn-xs">Set Rate Shaper '.. i ..'</button></form></td></tr>')
      else
	 print("</td></tr>")
      end
end
print [[</table>
  NOTES
<ul>
<li>Shaper 0 is the default shaper used for local hosts that have no shaper defined.
<li>Set max rate to:<ul><li>-1 for no shaping<li>0 for dropping all traffic</ul>
</ul>
]]

elseif(page == "filtering") then
   policy_key = "ntopng.prefs.".. ifid ..".l7_policy"

   -- ====================================

   if((_GET["new_vlan"] ~= nil) and (_GET["new_network"] ~= nil)) then
      -- We need to check if this network is local or not
      network_key = _GET["new_network"].."@".._GET["new_vlan"]
      ntop.setHashCache(policy_key, network_key, "")
   end

   if(_GET["delete_network"] ~= nil) then
      ntop.delHashCache(policy_key, _GET["delete_network"])
   end

   net = _GET["network"]

   if(net ~= nil) then
      if(findString(net, "@") == nil) then
	 net = net.."@0"
      end

      if(ntop.getHashCache(policy_key, net) == "") then
	 ntop.setHashCache(policy_key, net, "")
      end
   end

   any_net = "0.0.0.0/0@0"
   --io.write('key: '..key..'\n')
   nets = ntop.getHashKeysCache(key, any_net)

   if((nets == nil) or (nets == "")) then
      nets = ntop.getHashKeysCache(policy_key)
   end

   -- tprint(nets)
   if((net == nil) and (nets ~= nil)) then
      -- If there is not &network= parameter then use the first network available
      for k,v in pairsByKeys(nets, asc) do
	 net = k
	 break
      end
   end

   -- io.write(net.."\n")
   if((net ~= nil) and (_GET["blacklist"] ~= nil)) then
      ntop.setHashCache(policy_key, net, _GET["blacklist"])

      -- ******************************
      ingress_shaper_id = _GET["ingress_shaper_id"]
      if(ingress_shaper_id == nil) then ingress_shaper_id = 0 end
      key = "ntopng.prefs.".. ifid ..".l7_policy_ingress_shaper_id"
      ntop.setHashCache(key, net, ingress_shaper_id)
      -- ******************************
      egress_shaper_id = _GET["egress_shaper_id"]
      if(egress_shaper_id == nil) then egress_shaper_id = 0 end
      key = "ntopng.prefs.".. ifid ..".l7_policy_egress_shaper_id"
      ntop.setHashCache(key, net, egress_shaper_id)
      -- ******************************
      interface.reloadL7Rules(net)
      -- io.write("reloading shapers for "..net.."\n")
   end

   selected_network = net
   if(selected_network == nil) then
      selected_network = any_net
   end

   print [[
  <form id="ndpiprotosform" action="]] print(ntop.getHttpPrefix()) print [[/lua/if_stats.lua" method="get">
  <input type=hidden name=page value=filtering>
  <table class="table table-striped table-bordered">
  <tr><th colspan=2>Manage Traffic Filtering Policies</th></tr>
  <tr><th width=10%>Network:</th><td> <select name="network" id="network">
]]
   selected_found = false
   if(nets ~= nil) then
      for k,v in pairsByKeys(nets, asc) do
	 if(k ~= "") then
	    print("\t<option")
	    if(k == selected_network) then print(" selected") end
	    print(">"..k.."</option>\n")
	    selected_found = true
	 end
      end
   end

print [[
</select>

<script>
$("#network").change(function() {
   document.location.href = "]] print(ntop.getHttpPrefix()) print [[/lua/if_stats.lua?page=filtering&network="+$("#network").val();
});
</script>
</form>
]]

if((selected_found == true)
      and (string.contains(selected_network, "/32")
	   or string.contains(selected_network, "/128"))) then
   nw = string.gsub(selected_network, "/32", "");
   nw = string.gsub(nw, "/128", "");
   print("&nbsp;[ <A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..nw.."\"><i class=\"fa fa-desktop fa-lg\"></i> Show Host</A> ] ")
end

print(' [ <A HREF=/lua/if_stats.lua?page=filtering&delete_network='..selected_network..'> <i class="fa fa-trash-o fa-lg"></i> Delete '.. selected_network ..'</A> ]')
print('</td></tr>')

-- ******************************************

print [[
<tr><th>Ingress Shaper Id</th><td>
<select name="ingress_shaper_id" id="ingress_shaper_id">
   ]]

   key = "ntopng.prefs.".. ifid ..".l7_policy_ingress_shaper_id"
   ingress_shaper_id = ntop.getHashCache(key, selected_network)
   if(ingress_shaper_id == "") then ingress_shaper_id = 0 else ingress_shaper_id = tonumber(ingress_shaper_id) end
   if((ingress_shaper_id < 0) or (ingress_shaper_id > max_num_shapers)) then ingress_shaper_id = 0 end

   for i=0,max_num_shapers-1 do
      print("<option value="..i)
      if(i == ingress_shaper_id) then print(" selected") end
      print(">"..i.." (")

      max_rate = ntop.getHashCache(shaper_key, i)

      print(maxRateToString(max_rate)..")</option>\n")
   end

print [[
</select><br>&nbsp;<br><small>Specify the max <u>ingress</u> transmission bandwidth to be associated to this network/host.</small></td></tr>
   ]]

-- ******************************************

print [[
<tr><th>Egress Shaper Id</th><td>
<select name="egress_shaper_id" id="egress_shaper_id">
   ]]

   key = "ntopng.prefs.".. ifid ..".l7_policy_egress_shaper_id"
   egress_shaper_id = ntop.getHashCache(key, selected_network)
   if(egress_shaper_id == "") then egress_shaper_id = 0 else egress_shaper_id = tonumber(egress_shaper_id) end
   if((egress_shaper_id < 0) or (egress_shaper_id > max_num_shapers)) then egress_shaper_id = 0 end

   for i=0,max_num_shapers-1 do
      print("<option value="..i)
      if(i == egress_shaper_id) then print(" selected") end
      print(">"..i.." (")

      max_rate = ntop.getHashCache(shaper_key, i)

      if((max_rate == nil) or (max_rate == "")) then max_rate = -1 end
      print(maxRateToString(tonumber(max_rate)))
      print(")</option>\n")
   end

print [[
</select><br>&nbsp;<br><small>Specify the max <u>egress</u> transmission bandwidth to be associated to this network/host.</small></td></tr>
   ]]

-- ******************************************

print [[
<tr><td colspan=2>
  <input type=hidden id=blacklist name=blacklist value="">
  <select multiple="multiple" size="10" name="ndpiprotos">
]]

blacklist = { }
rules = ntop.getHashCache(policy_key, selected_network)
if((rules ~= nil) and (string.len(rules) > 0)) then
   local protos = split(rules, ",")
   for k,v in pairs(protos) do
      blacklist[v] = 1
   end
end

   protos = interface.getnDPIProtocols()

   for k,v in pairsByKeys(protos, asc) do
      if((k ~= "GRE")
	    and (k ~= "BGP")
	    and (k ~= "IGMP")
	    and (k ~= "IPP")
	    and (k ~= "IP_in_IP")
	    and (k ~= "OSPF")
	    and (k ~= "PPTP")
	    and (k ~= "SCTP")
	    and (k ~= "TFTP")
      ) then
	 print("<option value=\""..v.."\"")

	 --print(""..v.."<p>")
	 if(blacklist[v] ~= nil) then
	    print(" selected=\"selected\"")
	 end

	 print(">"..k.."</option>\n")
      end
   end

   print [[
    </select>
    </td></tr>
    <tr><td colspan=2><button type="submit" class="btn btn-primary btn-block">Set Protocol Policy and Shaper</button></td></tr>

<script>
    function validateAddNetworkForm(network_field_id, vlan_field_id) {
      if(is_network_mask($(network_field_id).val())) {
	 var vlan= $(vlan_field_id).val();
	 if((vlan >= 0) && (vlan <= 4095)) {
	   $('#badnet').hide();
	   return(true);
	 } else {
	   $('#badnet').show();
	   return false;
	 }
      } else {
       //alert("Invalid network specified");
      $('#badnet').show();
      return false;
     }
    }
</script>



<tr><th colspan=2>&nbsp;</th></tr>
<tr><th colspan=2>Add VLAN/Network To Filter</th></tr>

<tr><td colspan=2>
<div id="badnet" class="alert alert-danger" style="display: none">
    <strong>Warning</strong> Invalid VLAN/network specified.
</div>

<div class="container-fluid">
  <div class="row">

    <div class="col-md-6">
      <form class="form-inline" onsubmit="return validateAddNetworkForm('#new_network', '#new_vlan');">
      <div class="form-group">
      <input type=hidden name=page value="filtering">
      Local Network :
      <select name="new_network" id="new_network">
          ]]
       locals = ntop.getLocalNetworks()
       for s,_ in pairs(locals) do
          print('<option value="'..s..'">'..s..'</option>\n')
       end
      print [[
      </select>
      VLAN <input type="text" class=form-control id="new_vlan" name="new_vlan" value="0" size=4>
      <button type="submit" class="btn btn-primary btn-sm">Add Local VLAN/Network</button>
      </div>
      </form>
    </div>

    <div class="col-md-6">
      <form class="form-inline" onsubmit="return validateAddNetworkForm('#new_custom_network', '#new_custom_vlan');">
      <div class="form-group">
      <input type=hidden name=page value="filtering">
      Network (CIDR) <input type="text" class=form-control id="new_custom_network" name="new_network" size=14>
      VLAN <input type="text" class=form-control id="new_custom_vlan" name="new_vlan" value="0" size=4>
      <button type="submit" class="btn btn-primary btn-sm">Add Custom VLAN/Network</button>
      </div>
      </form>
    </div>

  </div>
</div>

</td>

</tr>
 </table>
  </form>
  <script>
    var ndpiprotos1 = $('select[name="ndpiprotos"]').bootstrapDualListbox({
			nonSelectedListLabel: 'White Listed Protocols for ]] print(selected_network) print [[',
			selectedListLabel: 'Black Listed Protocols for ]] print(selected_network) print [[',
			moveOnSelect: false
		      });
    $("#ndpiprotosform").submit(function() {
      // alert($('[name="ndpiprotos"]').val());
      $('#blacklist').val($('[name="ndpiprotos"]').val());
      return true;
    });
  </script>
]]
elseif page == "report" then
   dofile(dirs.installdir .. "/pro/scripts/lua/traffic_report.lua")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

print("<script>\n")
print("var last_pkts  = " .. ifstats.stats.packets .. ";\n")
print("var last_drops = " .. ifstats.stats.drops .. ";\n")

if(ifstats["bridge.device_a"] ~= nil) then
   print("var last_epoch  = 0;\n")
   print("var a_to_b_last_in_pkts  = " .. ifstats["bridge.a_to_b.in_pkts"] .. ";\n")
   print("var a_to_b_last_out_pkts  = " .. ifstats["bridge.a_to_b.out_pkts"] .. ";\n")
   print("var a_to_b_last_in_bytes  = " .. ifstats["bridge.a_to_b.in_bytes"] .. ";\n")
   print("var a_to_b_last_out_bytes  = " .. ifstats["bridge.a_to_b.out_bytes"] .. ";\n")
   print("var a_to_b_last_filtered_pkts  = " .. ifstats["bridge.a_to_b.filtered_pkts"] .. ";\n")
   print("var a_to_b_last_shaped_pkts  = " .. ifstats["bridge.a_to_b.shaped_pkts"] .. ";\n")
   print("var a_to_b_last_num_pkts_send_buffer_full  = " .. ifstats["bridge.a_to_b.num_pkts_send_buffer_full"] .. ";\n")
   print("var a_to_b_last_num_pkts_send_error  = " .. ifstats["bridge.a_to_b.num_pkts_send_error"] .. ";\n")

   print("var b_to_a_last_in_pkts  = " .. ifstats["bridge.b_to_a.in_pkts"] .. ";\n")
   print("var b_to_a_last_out_pkts  = " .. ifstats["bridge.b_to_a.out_pkts"] .. ";\n")
   print("var b_to_a_last_in_bytes  = " .. ifstats["bridge.b_to_a.in_bytes"] .. ";\n")
   print("var b_to_a_last_out_bytes  = " .. ifstats["bridge.b_to_a.out_bytes"] .. ";\n")
   print("var b_to_a_last_filtered_pkts  = " .. ifstats["bridge.b_to_a.filtered_pkts"] .. ";\n")
   print("var b_to_a_last_shaped_pkts  = " .. ifstats["bridge.b_to_a.shaped_pkts"] .. ";\n")
   print("var b_to_a_last_num_pkts_send_buffer_full  = " .. ifstats["bridge.b_to_a.num_pkts_send_buffer_full"] .. ";\n")
   print("var b_to_a_last_num_pkts_send_error  = " .. ifstats["bridge.b_to_a.num_pkts_send_error"] .. ";\n")
end

if(ifstats.zmqRecvStats ~= nil) then
   print("var last_zmq_time = 0;\n")
   print("var last_zmq_flows = ".. ifstats.zmqRecvStats.flows .. ";\n")
   print("var last_zmq_events = ".. ifstats.zmqRecvStats.events .. ";\n")
   print("var last_zmq_counters = ".. ifstats.zmqRecvStats.counters .. ";\n")
end
   
print [[
setInterval(function() {
      $.ajax({
	  type: 'GET',
	  url: ']]
print (ntop.getHttpPrefix())
print [[/lua/network_load.lua',
	  data: { ifname: "]] print(tostring(interface.name2id(ifstats.name))) print [[" },
	  success: function(rsp) {
	var v = bytesToVolume(rsp.bytes);
	$('#if_bytes').html(v);

        if (typeof rsp.zmqRecvStats !== 'undefined') {
           var diff, time_diff, label;
           var now = (new Date()).getTime();

           if(last_zmq_time > 0) {
              time_diff = now - last_zmq_time;
              diff = rsp.zmqRecvStats.flows - last_zmq_flows;

              if(diff > 0) {
                 rate = ((diff * 1000)/time_diff).toFixed(1);
                 label = " ["+rate+" Flows/sec] "+get_trend(1,0);
              } else {
                 label = " "+get_trend(0,0);
              }
           } else {
              label = " "+get_trend(0,0);
           }
           $('#if_zmq_flows').html(addCommas(rsp.zmqRecvStats.flows)+label); 
           $('#if_zmq_events').html(addCommas(rsp.zmqRecvStats.events)+" "+get_trend(rsp.zmqRecvStats.events, last_zmq_events)); 
           $('#if_zmq_counters').html(addCommas(rsp.zmqRecvStats.counters)+" "+get_trend(rsp.zmqRecvStats.counters, last_zmq_counters)); 

           last_zmq_flows = rsp.zmqRecvStats.flows;
           last_zmq_events = rsp.zmqRecvStats.events;
           last_zmq_counters = rsp.zmqRecvStats.counters;
           last_zmq_time = now;
        }

	$('#if_pkts').html(addCommas(rsp.packets)+"]]

print(" Pkts\");")
print [[
	var pctg = 0;
	var drops = "";
	var last_pkt_retransmissions = ]] print(ifstats.tcpPacketStats.retransmissions) print [[;
	var last_pkt_ooo =  ]] print(ifstats.tcpPacketStats.out_of_order) print [[;
	var last_pkt_lost = ]] print(ifstats.tcpPacketStats.lost) print [[;

	$('#pkt_retransmissions').html(fint(rsp.tcpPacketStats.retransmissions)+" Pkts"); $('#pkt_retransmissions_trend').html(get_trend(last_pkt_retransmissions, rsp.tcpPacketStats.retransmissions));
	$('#pkt_ooo').html(fint(rsp.tcpPacketStats.out_of_order)+" Pkts");  $('#pkt_ooo_trend').html(get_trend(last_pkt_ooo, rsp.tcpPacketStats.out_of_order));
	$('#pkt_lost').html(fint(rsp.tcpPacketStats.lost)+" Pkts"); $('#pkt_lost_trend').html(get_trend(last_pkt_lost, rsp.tcpPacketStats.lost));
	last_pkt_retransmissions = rsp.tcpPacketStats.retransmissions;
	last_pkt_ooo = rsp.tcpPacketStats.out_of_order;
	last_pkt_lost = rsp.tcpPacketStats.lost;

	$('#pkts_trend').html(get_trend(last_pkts, rsp.packets));
	$('#drops_trend').html(get_trend(last_drops, rsp.drops));
	last_pkts = rsp.packets;
	last_drops = rsp.drops;

	if((rsp.packets+rsp.drops) > 0) { pctg = ((rsp.drops*100)/(rsp.packets+rsp.drops)).toFixed(2); }
	if(rsp.drops > 0) { drops = '<span class="label label-danger">'; }
	drops = drops + addCommas(rsp.drops)+" ]]

print("Pkts")
print [[";

	if(pctg > 0)      { drops = drops + " [ "+pctg+" % ]"; }
	if(rsp.drops > 0) { drops = drops + '</span>';         }
	$('#if_drops').html(drops);

        $('#exported_flows').html(fint(rsp.flow_export_count));
        $('#exported_flows_rate').html(Math.round(rsp.flow_export_rate * 100) / 100);
        if(rsp.flow_export_drops > 0) {
          $('#exported_flows_drops')
            .addClass("label label-danger")
            .html(rsp.flow_export_drops);
          if(rsp.flow_export_count > 0) {
            $('#exported_flows_drops_pct')
              .addClass("label label-danger")
              .html("[" + Math.round(rsp.flow_export_drops / rsp.flow_export_count * 100 * 1000) / 1000 + "%]");
          }
        }
]]

if(ifstats["bridge.device_a"] ~= nil) then
print [[
   epoch_diff = rsp["epoch"]-last_epoch;
   $('#a_to_b_in_pkts').html(addCommas(rsp["a_to_b_in_pkts"])+" Pkts "+get_trend(a_to_b_last_in_pkts, rsp["a_to_b_in_pkts"]));
   if((last_epoch > 0) && (epoch_diff > 0)) {
      /* pps = (rsp["a_to_b_in_pkts"]-a_to_b_last_in_pkts) / epoch_diff; */
      bps = 8*(rsp["a_to_b_in_bytes"]-a_to_b_last_in_bytes) / epoch_diff;
      $('#a_to_b_in_pps').html(" ["+fbits(bps)+"]");
    }
   $('#a_to_b_out_pkts').html(addCommas(rsp["a_to_b_out_pkts"])+" Pkts "+get_trend(a_to_b_last_out_pkts, rsp["a_to_b_out_pkts"]));
   if((last_epoch > 0) && (epoch_diff > 0)) {
      /* pps = (rsp["a_to_b_out_pkts"]-a_to_b_last_out_pkts) / epoch_diff; */
      bps = 8*(rsp["a_to_b_out_bytes"]-a_to_b_last_out_bytes) / epoch_diff;
      $('#a_to_b_out_pps').html(" ["+fbits(bps)+"]");
    }

   $('#a_to_b_filtered_pkts').html(addCommas(rsp["a_to_b_filtered_pkts"])+" Pkts "+get_trend(a_to_b_last_filtered_pkts, rsp["a_to_b_filtered_pkts"]));
   $('#a_to_b_shaped_pkts').html(addCommas(rsp["a_to_b_shaped_pkts"])+" Pkts "+get_trend(a_to_b_last_shaped_pkts, rsp["a_to_b_shaped_pkts"]));
   $('#a_to_b_num_pkts_send_error').html(addCommas(rsp["a_to_b_num_pkts_send_error"])+" Pkts "+get_trend(a_to_b_last_num_pkts_send_error, rsp["a_to_b_num_pkts_send_error"]));
   $('#a_to_b_num_pkts_send_buffer_full').html(addCommas(rsp["a_to_b_num_pkts_send_buffer_full"])+" Pkts "+get_trend(a_to_b_last_num_pkts_send_buffer_full, rsp["a_to_b_num_pkts_send_buffer_full"]));

   $('#b_to_a_in_pkts').html(addCommas(rsp["b_to_a_in_pkts"])+" Pkts "+get_trend(b_to_a_last_in_pkts, rsp["b_to_a_in_pkts"]));
   if((last_epoch > 0) && (epoch_diff > 0)) {
      /* pps = (rsp["b_to_a_in_pkts"]-b_to_a_last_in_pkts) / epoch_diff; */
      bps = 8*(rsp["b_to_a_in_bytes"]-b_to_a_last_in_bytes) / epoch_diff;
      $('#b_to_a_in_pps').html(" ["+fbits(bps)+"]");
    }
   $('#b_to_a_out_pkts').html(addCommas(rsp["b_to_a_out_pkts"])+" Pkts "+get_trend(b_to_a_last_out_pkts, rsp["b_to_a_out_pkts"]));
   if((last_epoch > 0) && (epoch_diff > 0)) {
      /* pps = (rsp["b_to_a_out_pkts"]-b_to_a_last_out_pkts) / epoch_diff; */
      bps = 8*(rsp["b_to_a_out_bytes"]-b_to_a_last_out_bytes) / epoch_diff;
      $('#b_to_a_out_pps').html(" ["+fbits(bps)+"]");
    }
   $('#b_to_a_filtered_pkts').html(addCommas(rsp["b_to_a_filtered_pkts"])+" Pkts "+get_trend(b_to_a_last_filtered_pkts, rsp["b_to_a_filtered_pkts"]));
   $('#b_to_a_shaped_pkts').html(addCommas(rsp["b_to_a_shaped_pkts"])+" Pkts "+get_trend(b_to_a_last_shaped_pkts, rsp["b_to_a_shaped_pkts"]));
   $('#b_to_a_num_pkts_send_error').html(addCommas(rsp["b_to_a_num_pkts_send_error"])+" Pkts "+get_trend(b_to_a_last_num_pkts_send_error, rsp["b_to_a_num_pkts_send_error"]));
   $('#b_to_a_num_pkts_send_buffer_full').html(addCommas(rsp["b_to_a_num_pkts_send_buffer_full"])+" Pkts "+get_trend(b_to_a_last_num_pkts_send_buffer_full, rsp["b_to_a_num_pkts_send_buffer_full"]));

   a_to_b_last_in_pkts = rsp["a_to_b_in_pkts"];
   a_to_b_last_out_pkts = rsp["a_to_b_out_pkts"];
   a_to_b_last_in_bytes = rsp["a_to_b_in_bytes"];
   a_to_b_last_out_bytes = rsp["a_to_b_out_bytes"];
   a_to_b_last_filtered_pkts = rsp["a_to_b_filtered_pkts"];
   a_to_b_last_shaped_pkts = rsp["a_to_b_shaped_pkts"];
   a_to_b_last_num_pkts_send_buffer_full = rsp["a_to_b_num_pkts_send_buffer_full"];
   a_to_b_last_num_pkts_send_error = rsp["a_to_b_num_pkts_send_error"];

   b_to_a_last_in_pkts = rsp["b_to_a_in_pkts"];
   b_to_a_last_out_pkts = rsp["b_to_a_out_pkts"];
   b_to_a_last_in_bytes = rsp["b_to_a_in_bytes"];
   b_to_a_last_out_bytes = rsp["b_to_a_out_bytes"];
   b_to_a_last_filtered_pkts = rsp["b_to_a_filtered_pkts"];
   b_to_a_last_shaped_pkts = rsp["b_to_a_shaped_pkts"];
   b_to_a_last_num_pkts_send_buffer_full = rsp["b_to_a_num_pkts_send_buffer_full"];
   b_to_a_last_num_pkts_send_error = rsp["b_to_a_num_pkts_send_error"];
   last_epoch = rsp["epoch"];
]]
end

print [[
	   }
	       });
       }, 3000)

</script>

]]

print [[
	 <script type="text/javascript" src="]] print(ntop.getHttpPrefix()) print [[/js/jquery.tablesorter.js"></script>
<script>
$(document).ready(function()
    {
	$("#myTable").tablesorter();
    }
);
</script>
]]
