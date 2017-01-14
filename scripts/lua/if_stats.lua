--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
   require "common"
end

local json = require "dkjson"

require "lua_utils"
require "prefs_utils"
require "graph_utils"
require "alert_utils"
require "db_utils"

if ntop.isPro() then
   shaper_utils = require("shaper_utils")
end

sendHTTPHeader('text/html; charset=iso-8859-1')

page = _GET["page"]
if_name = _GET["if_name"]
ifid = (_GET["id"] or _GET["ifId"])
ifname_clean = "iface_"..tostring(ifid)
msg = ""

function inline_input_form(name, placeholder, tooltip, value, can_edit, input_opts, input_clss)
   print [[<form class="form-inline" style="margin-bottom: 0px;" method="post">]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

   if(can_edit) then
      print('<input style="width:12em;" title="'..tooltip..'" '..(input_opts or "")..' class="form-control '..(input_clss or "")..'" name="'..name..'" placeholder="'..placeholder..'" value="')
      if(value ~= nil) then print(value) end
      print[["></input>&nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>]]
   else
      if(value ~= nil) then print(value) end
   end
   print("</form>\n")
end

if(_POST["switch_interface"] ~= nil) then
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

ifstats = interface.getStats()

-- this is a user-browseable page, so we must return counters from
-- the latest reset as the user may have chosen to reset statistics at some point
if ifstats.stats and ifstats.stats_since_reset then
   -- override stats with the values calculated from the latest user reset
   for k, v in pairs(ifstats.stats_since_reset) do
      ifstats.stats[k] = v
   end
end

if (isAdministrator()) then
   if(_POST["custom_name"] ~=nil) then
	 -- TODO move keys to new schema: replace ifstats.name with ifid
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.name',_POST["custom_name"])
   end

   if(_POST["scaling_factor"] ~= nil) then
	 local sf = tonumber(_POST["scaling_factor"])
	 if(sf == nil) then sf = 1 end
	 ntop.setCache(getRedisIfacePrefix(ifid)..'.scaling_factor',tostring(sf))
	 interface.loadScalingFactorPrefs()
   end

   if is_packetdump_enabled then
      if(_POST["dump_all_traffic"] ~= nil) then
	 page = "packetdump"
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_all_traffic',_POST["dump_all_traffic"])
      end
      if(_POST["dump_traffic_to_tap"] ~= nil) then
	 page = "packetdump"
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_tap',_POST["dump_traffic_to_tap"])
      end
      if(_POST["dump_traffic_to_disk"] ~= nil) then
	 page = "packetdump"
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_disk',_POST["dump_traffic_to_disk"])
      end
      if(_POST["dump_unknown_to_disk"] ~= nil) then
	 page = "packetdump"
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_unknown_disk',_POST["dump_unknown_to_disk"])
      end
      if(_POST["dump_security_to_disk"] ~= nil) then
	 page = "packetdump"
	 ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_security_disk',_POST["dump_security_to_disk"])
      end

      if(_POST["sampling_rate"] ~= nil) then
	 if(tonumber(_POST["sampling_rate"]) ~= nil) then
	    page = "packetdump"
	    val = ternary(_POST["sampling_rate"] ~= "0", _POST["sampling_rate"], "1")
	    ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_sampling_rate', val)
	 end
      end
      if(_POST["max_pkts_file"] ~= nil) then
	 if(tonumber(_POST["max_pkts_file"]) ~= nil) then
	    page = "packetdump"
	    ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_pkts_file',_POST["max_pkts_file"])
	 end
      end
      if(_POST["max_sec_file"] ~= nil) then
	 if(tonumber(_POST["max_sec_file"]) ~= nil) then
	    page = "packetdump"
	    ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_sec_file',_POST["max_sec_file"])
	 end
      end
      if(_POST["max_files"] ~= nil) then
	 if(tonumber(_POST["max_files"]) ~= nil) then
	    page = "packetdump"
	    local max_files_size = tonumber(_POST["max_files"])
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
      print("\n<li class=\"active\"><a href=\"#\">")
   elseif interface.isPcapDumpInterface() == false then
      print("\n<li><a href=\""..url.."&page=alerts\">")
   end

   if interface.isPcapDumpInterface() == false then
      print("<i class=\"fa fa-warning fa-lg\"></i></a>")
      print("</li>")
   end
end

if(ntop.isEnterprise()) then
      if(page == "traffic_report") then
         print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-file-text report-icon'></i></a></li>\n")
      else
         print("\n<li><a href=\""..url.."&page=traffic_report\"><i class='fa fa-file-text report-icon'></i></a></li>")
      end
else
      print("\n<li><a href=\"#\" title=\""..i18n('enterpriseOnly').."\"><i class='fa fa-file-text report-icon'></i></A></li>\n")
end

if(isAdministrator()) then
   if(page == "config") then
      print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-cog fa-lg\"></i></a></li>\n")
   elseif interface.isPcapDumpInterface() == false then
      print("\n<li><a href=\""..url.."&page=config\"><i class=\"fa fa-cog fa-lg\"></i></a></li>")
   end
end

if(ifstats.inline and isAdministrator()) then
   if(page == "filtering") then
      print("<li class=\"active\"><a href=\""..url.."&page=filtering\">Traffic Policing</a></li>")
   else
      print("<li><a href=\""..url.."&page=filtering\">Traffic Policing</a></li>")
   end
end

local ifname_clean = "iface_"..tostring(ifid)

if _POST["re_arm_minutes"] ~= nil then
   page = "config"
   ntop.setHashCache(get_re_arm_alerts_hash_name(), get_re_arm_alerts_hash_key(ifId, ifname_clean), _POST["re_arm_minutes"])
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
         print("<td colspan=2>&nbsp;</td>\n")
      end
      print("</tr>\n")
   end

   local is_physical_iface = (interface.isPacketInterface()) and (interface.isPcapDumpInterface() == false)
   local is_bridge_iface = (ifstats["bridge.device_a"] ~= nil) and (ifstats["bridge.device_b"] ~= nil)

   if not is_bridge_iface then
      print('<tr><th width="250">Name</th><td colspan="2">' .. ifstats.name..'</td>\n')
   else
      print("<tr><th>Bridge</th><td colspan=2>"..ifstats["bridge.device_a"].." <i class=\"fa fa-arrows-h\"> "..ifstats["bridge.device_b"].."</td>")
   end

   if not interface.isPcapDumpInterface() then
      if((ifstats.name ~= nil) and (ifstats.name ~= "dummy")) then
          print('<th>Custom Name</th><td colspan="3">')
          label = getInterfaceNameAlias(ifstats.name)
          inline_input_form("custom_name", "Custom Name",
         "Specify an alias for the interface",
         label, isAdministrator(), 'autocorrect="off" spellcheck="false" pattern="^[_\\-a-zA-Z0-9 ]*$"')
          print("</td></tr>\n")
      else
         print("<td colspan=2></td></tr>")
      end
   end

   if not is_bridge_iface then
      if is_physical_iface then
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
         end
      end

      if(ifstats.ip_addresses ~= "") then
         tokens = split(ifstats.ip_addresses, ",")

      if(tokens ~= nil) then
         print("<tr><th width=250>IP Address</th><td colspan=5>")
         local addresses = {}

         for _,s in pairs(tokens) do
            t = string.split(s, "/")
            host = interface.getHostInfo(t[1])

            if(host ~= nil) then
               addresses[#addresses+1] = "<a href="..ntop.getHttpPrefix().."/lua/host_details.lua?host="..t[1]..">".. t[1].."</a>"
            else
               addresses[#addresses+1] = t[1]
            end
         end

         print(table.concat(addresses, ", "))

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
   -- print("<th nowrap>sFlow Counter Updates</th><td width=20%><span id=if_zmq_counters>"..formatValue(ifstats.zmqRecvStats.counters).."</span></tr>")
   print("<th nowrap>ZMQ Message Drops</th><td width=20%><span id=if_zmq_msg_drops>"..formatValue(ifstats.zmqRecvStats.zmq_msg_drops).."</span></tr>")
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
   print("</span>&nbsp;<span id=drops_trend></span></td><td colspan=3>")
   print("</td></tr>\n")

   if(prefs.is_dump_flows_enabled and ifstats.isView == false) then
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

   if (isAdministrator() and ifstats.isView == false) then
      print("<tr><th width=250>Reset Counters</th>")
      print("<td colspan=4>")

      local cls = ""
      local tot	= ifstats.stats.bytes + ifstats.stats.packets + ifstats.stats.drops
      if(ifstats.stats.flow_export_count ~= nil) then
      	tot = tot + ifstats.stats.flow_export_count + ifstats.stats.flow_export_drops
      end
      
      if tot == 0 then
	 cls = " disabled"
      end
      print('<button id="btn_reset_all" type="button" class="btn btn-default btn-xs'..cls..'" onclick="resetInterfaceCounters(false);">All Counters</button>&nbsp;')

      cls = ""
      if(ifstats.stats.flow_export_count ~= nil) then
        if ifstats.stats.drops + ifstats.stats.flow_export_drops == 0 then
	 cls = " disabled"
	end
      end
      print('<button id="btn_reset_drops" type="button" class="btn btn-default btn-xs'..cls..'" onclick="resetInterfaceCounters(true);">Drops Only</button>')
      print("</td>")

      print("</tr>\n")
   end

   if((ifstats["bridge.device_a"] ~= nil) and (ifstats["bridge.device_b"] ~= nil)) then
      print("<tr><th colspan=7>Bridged Traffic</th></tr>\n")
      print("<tr><th nowrap>Interface Direction</th><th nowrap>Ingress Packets</th><th nowrap>Egress Packets</th><th nowrap>Shaped/Filtered Packets</th><th nowrap>Send Error</th><th nowrap>Buffer Full</th></tr>\n")
      print("<tr><th>".. ifstats["bridge.device_a"] .. " <i class=\"fa fa-arrow-right\"></i> ".. ifstats["bridge.device_b"] .."</th><td><span id=a_to_b_in_pkts>".. formatPackets(ifstats["bridge.a_to_b.in_pkts"]) .."</span> <span id=a_to_b_in_pps></span></td>")
      print("<td><span id=a_to_b_out_pkts>".. formatPackets(ifstats["bridge.a_to_b.out_pkts"]) .."</span> <span id=a_to_b_out_pps></span></td>")
      print("<td><span id=a_to_b_filtered_pkts>".. formatPackets(ifstats["bridge.a_to_b.filtered_pkts"]) .."</span></td>")

      print("<td><span id=a_to_b_num_pkts_send_error>".. formatPackets(ifstats["bridge.a_to_b.num_pkts_send_error"]) .."</span></td>")
      print("<td><span id=a_to_b_num_pkts_send_buffer_full>".. formatPackets(ifstats["bridge.a_to_b.num_pkts_send_buffer_full"]) .."</span></td>")

      print("</tr>\n")

      print("<tr><th>".. ifstats["bridge.device_b"] .. " <i class=\"fa fa-arrow-right\"></i> ".. ifstats["bridge.device_a"] .."</th><td><span id=b_to_a_in_pkts>".. formatPackets(ifstats["bridge.b_to_a.in_pkts"]) .."</span> <span id=b_to_a_in_pps></span></td>")
      print("<td><span id=b_to_a_out_pkts>"..formatPackets( ifstats["bridge.b_to_a.out_pkts"]) .."</span> <span id=b_to_a_out_pps></span></td>")
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
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	       print('<input type="hidden" name="dump_all_traffic" value="'..dump_all_traffic_value..'"><input type="checkbox" value="1" '..dump_all_traffic_checked..' onclick="this.form.submit();">  Dump All Traffic')
	       print('</input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%>Packet Dump To Disk</th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	       print('<input type="hidden" name="dump_traffic_to_disk" value="'..dump_traffic_value..'"><input type="checkbox" value="1" '..dump_traffic_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> Dump Traffic To Disk')
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
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	       print('<input type="hidden" name="dump_unknown_to_disk" value="'..dump_unknown_value..'"><input type="checkbox" value="1" '..dump_unknown_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> Dump Unknown Traffic To Disk </input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%></th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	       print('<input type="hidden" name="dump_security_to_disk" value="'..dump_security_value..'"><input type="checkbox" value="1" '..dump_security_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> Dump Traffic To Disk On Security Alert </input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th>Packet Dump To Tap</th><td>")
   if(interface.getInterfaceDumpTapName() ~= "") then
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	       print('><input type="hidden" name="dump_traffic_to_tap" value="'..dump_traffic_tap_value..'"><input type="checkbox" value="1" '..dump_traffic_tap_checked..' onclick="this.form.submit();"> <i class="fa fa-filter fa-lg"></i> Dump Traffic To Tap ')
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
   print[[<form class="form-inline" style="margin-bottom: 0px;" method="post">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
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
    <form class="form-inline" style="margin-bottom: 0px;" method="post">]]
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
    <form class="form-inline" style="margin-bottom: 0px;" method="post">]]
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
    <form class="form-inline" style="margin-bottom: 0px;" method="post">]]
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

   drawAlertSourceSettings(ifname_clean,
      i18n("show_alerts.iface_delete_config_btn"), i18n("show_alerts.iface_delete_config_confirm"),
      "if_stats.lua", {ifid=ifid},
      if_name)

elseif(page == "config") then
local re_arm_minutes = nil
local if_name = ifstats.name

   if(isAdministrator()) then
      trigger_alerts = _POST["trigger_alerts"]
      if(trigger_alerts ~= nil) then
	 if(trigger_alerts == "true") then
	    ntop.delHashCache(get_alerts_suppressed_hash_name(ifname), ifname_clean)
	 else
	    ntop.setHashCache(get_alerts_suppressed_hash_name(ifname), ifname_clean, trigger_alerts)
	 end
      end
   end

   re_arm_minutes = ntop.getHashCache(get_re_arm_alerts_hash_name(), get_re_arm_alerts_hash_key(ifId, ifname_clean))
   if re_arm_minutes == "" then re_arm_minutes=default_re_arm_minutes end

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
	    <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	 print('<input type="hidden" name="trigger_alerts" value="'..alerts_value..'"><input type="checkbox" value="1" '..alerts_checked..' onclick="this.form.submit();"> <i class="fa fa-exclamation-triangle fa-lg"></i> Trigger alerts for interface '..if_name..'</input>')
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	 print('</form>')
	 print('</td>')
	 print [[</tr>]]

   print[[<tr><form class="form-inline" style="margin-bottom: 0px;" method="post">]]
      print[[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
         <td style="text-align: left; white-space: nowrap;" ><b>Rearm minutes</b></td>
         <td>
            <input type="number" name="re_arm_minutes" min="1" value=]] print(tostring(re_arm_minutes)) print[[>
            &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
            <br><small>The rearm is the dead time between one alert generation and the potential generation of the next alert of the same kind. </small>
         </td>
    </form></tr>]]

    print("</table>")
elseif(page == "filtering") then
   if not isAdministrator() then
      error()
   end

   -- ====================================

   -- possibly decode parameters pairs
   local _POST = paramsPairsDecode(_POST)

function get_shapers_from_parameters(callback)
   local done = {}

   for option,value in pairs(_POST) do
      local sp = split(option, "ishaper_")
      local k = nil

      if #sp == 2 then
         k = sp[2]
      else
         sp = split(option, "eshaper_")
         if #sp == 2 then
            k = sp[2]
         end
      end

      if k ~= nil then
         if not done[k] then
            done[k] = true;
            callback(k, _POST["ishaper_"..k], _POST["eshaper_"..k])
         end
      end
   end
end
   local perPageProtos
   if tonumber(tablePreferences("protocolShapers")) == nil then
      perPageProtos = "10"
   else
      perPageProtos = tablePreferences("protocolShapers")
   end

   if (_GET["view_network"] ~= nil) then
      -- this is used by host_details.lua. Checks if the network exists, otherwise creates it
      if isin(_GET["view_network"],  shaper_utils.getNetworksList(ifid)) then
         -- network exists, redirect
         print('<script>window.location.hash = "#protocols"</script>')
      else
         -- network does not exist, trigger add action
         print('<script>var add_new_network_at_startup = "'.._GET["view_network"]..'"; window.location.hash = "#networks";</script>')
         _GET["view_network"] = nil
      end
   end

   if(_POST["edit_networks"] ~= nil) then
      local proto_shapers_cloned = false

      get_shapers_from_parameters(function(network_key, ingress_shaper, egress_shaper)
         if(_POST["clone"] ~= nil) then
            local clone_from = shaper_utils.addVlan0(_POST["clone"])

            -- clone everything from the network
            for _,proto_config in pairs(shaper_utils.getNetworkProtoShapers(ifid, clone_from)) do
               shaper_utils.setProtocolShapers(ifid, network_key, proto_config.protoId, proto_config.ingress, proto_config.egress, false)
               proto_shapers_cloned = true
            end
         else
            -- Do not create any additional protocol rule
            shaper_utils.setProtocolShapers(ifid, network_key, shaper_utils.NETWORK_SHAPER_DEFAULT_PROTO_KEY, ingress_shaper, egress_shaper, false)
         end

         interface.reloadL7Rules(network_key)
      end)
   end

   if((_POST["delete_network"] ~= nil) and (_POST["delete_network"] ~= shaper_utils.ANY_NETWORK)) then
      local target_net = _POST["delete_network"]

      shaper_utils.deleteNetwork(ifid, target_net)

      -- reload all the rules, and update hosts affected by removal
      interface.reloadL7Rules(target_net)
   end

   net = _GET["network"] or _POST["proto_network"] or _GET["view_network"]

   if(net ~= nil) then
      net = shaper_utils.addVlan0(net)
   end

   -- NB: this contains at least the 'default' network
   -- NB: this must be placed after 'delete_network' in order to fetch latest networks list
   nets = shaper_utils.getNetworksList(ifid)

   --tprint(nets)
   if(net == nil) then
      -- If there is not &network= parameter then use the first network available
      for _,k in ipairs(nets) do
         net = k
         break
      end
   end

   selected_network = net
   if(selected_network == nil) then
      selected_network = shaper_utils.ANY_NETWORK
   end

   local SHAPERS_MAX_RATE_KPBS = 100*1000*1000           -- 100 Gbit/s

   if(_POST["add_shapers"] ~= nil) then
      local num_added = 0
      local last_added = nil
      for shaper,mrate in pairs(_POST) do
         local sp = split(shaper, "shaper_")
         if #sp == 2 then
            local shaper_id = tonumber(sp[2])
            local max_rate = tonumber(mrate)
            --~ tprint(shaper_id.." "..max_rate)

            if(max_rate > SHAPERS_MAX_RATE_KPBS) then max_rate = -1 end
            if(max_rate < -1) then max_rate = -1 end

            shaper_utils.setShaperMaxRate(ifid, shaper_id, max_rate)
            num_added = num_added + 1
            last_added = shaper_id
         end
      end

      if num_added == 1 then
         print("<script>var shaper_just_added = "..last_added..";</script>")
      end

      interface.reloadShapers()
   end

   if(_POST["delete_shaper"] ~= nil) then
      local shaper_id = _POST["delete_shaper"]

      shaper_utils.deleteShaper(ifid, shaper_id)
   end

   if(_POST["proto_network"] ~= nil) then
      local target_net = _POST["proto_network"]

      if (_POST["del_l7_proto"] ~= nil) then
         local protocol_id = _POST["del_l7_proto"]
         shaper_utils.deleteProtocol(ifid, target_net, protocol_id)
      else
         -- set protocols policy for the network
         get_shapers_from_parameters(function(proto_id, ingress_shaper, egress_shaper)
            shaper_utils.setProtocolShapers(ifid, target_net, proto_id, ingress_shaper, egress_shaper, false)
         end)
      end

      -- Note: this could optimized to only reload this specific network
      interface.reloadL7Rules(target_net)
   end
   print [[
   <ul id="filterPageTabPanel" class="nav nav-tabs" role="tablist">
      <li><a data-toggle="tab" role="tab" href="#protocols">]] print(i18n("shaping.manage_networks")) print[[</a></li>
      <li><a data-toggle="tab" role="tab" href="#networks">]] print(i18n("shaping.define_networks")) print[[</a></li>
      <li><a data-toggle="tab" role="tab" href="#shapers">]] print(i18n("shaping.bandwidth_manager")) print[[</a></li>
   </ul>
   <div class="tab-content">]]


-- ******************************************

local shapers = shaper_utils.getSortedShapers(ifid)

function print_shapers(shapers, curshaper_id, terminator)
   terminator = terminator or "\n"
   if(curshaper_id == "") then curshaper_id = "0" else curshaper_id = tostring(curshaper_id) end

   for _,shaper in ipairs(shapers) do
      print("<option value="..shaper.id)
      if(shaper.id == curshaper_id) then print(" selected") end
      print(">"..shaper.id.." (")

      print(shaper_utils.shaperRateToString(shaper.rate)..")</option>"..terminator)
   end
end

-- ******************************************

locals = ntop.getLocalNetworks()
locals_empty = (next(locals) == nil)

-- ==== Define networks tab ====
print [[<div id="networks" class="tab-pane"><br>

<table class="table table-striped table-bordered"><tr><th>]] print(i18n("shaping.define_network")) print[[</th></tr><tr><td>
   <table class="table table-borderless"><tr>
      <div id="badnet" class="alert alert-danger" style="display: none"></div>
      <td><strong style="margin-right:1em">Network:</strong>
]]

print[[
         <input id="new_custom_network" type="text" class="form-control network-selector" style="]] if not locals_empty then print('display:none') end print[[">
]]

if not locals_empty then
   print('<select class="form-control network-selector" id="new_network" style="display:inline;">')
   for s,_ in pairs(locals) do
      print('<option value="'..s..'">'..s..'</option>\n')
   end
   print('</select>')
   print('<button type="button" class="btn btn-default btn-sm fa fa-pencil" onclick="toggleCustomNetworkMode();"></button></td>')
end
   print[[
   <td><strong style="margin-right:1em">VLAN</strong><input type="text" class="form-control" id="new_vlan" name="new_vlan" value="0" style="width:4em; display:inline;"></td>
   <td><strong style="margin-right:1em">Initial Policy:</strong>
         <div id="clone_proto_policy" class="btn-group" data-toggle="buttons-radio">
            <button id="bt_initial_empty" type="button" class="btn btn-primary active" value="empty">Default</button>
            <button id="bt_initial_clone" type="button" class="btn btn-default" value="clone">Clone</button>
         </div>
         <span id="clone_from_container" style="visibility:hidden;"><span style="margin: 0 1em 0 1em;">from</span>
            <select id="clone_from_select" class="form-control" style="display:inline; width:12em;">]]
for _,k in ipairs(nets) do
   if(k ~= "") then
      print("\t<option>"..k.."</option>\n")
   end
end
      print[[</select></span></td>
   </tr></table>
<button type="button" class="btn btn-primary" style="float:right; margin-right:2em;" onclick="checkNetworksFormCallback()">]] print(i18n("define")) print[[</button></td></tr>
</table>

NOTES:<ul>
   <li>These networks are used to define traffic policies </li>
</ul>

</div>
]]

-- ==== Manage policies tab ====

print [[<div id="protocols" class="tab-pane"><br>

<form id="editNetworksForm" method="post">
   <input type="hidden" name="edit_networks" value=""/>
   <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
</form>
<form id="deleteShapedProtocolForm" method="post">
   <input type="hidden" name="proto_network" value="]] print(net) print[[">
   <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   <input type="hidden" name="del_l7_proto" value="">
</form>

<table class="table table-striped table-bordered"><tr><th>Manage</th></tr><tr><td>
]] print(i18n("shaping.network_group")..":") print[[ <select id="proto_network" class="form-control network-selector" name="network" style="display:inline; margin-left:1em;">
]]
   for _,k in ipairs(nets) do
	 if(k ~= "") then
	    print("\t<option")
	    if(k == selected_network) then print(" selected") end
	    print(">"..shaper_utils.trimVlan0(k).."</option>\n")
	 end
   end
print("</select>")
this_net = shaper_utils.trimVlan0(selected_network)
if selected_network ~= shaper_utils.ANY_NETWORK then
   print[[<form id="deleteNetworkForm" style="display:inline;" method="post" action="?page=filtering#protocols">
     <input type="hidden" name="delete_network" value="]] print(selected_network) print[["/>
     <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
     [ <a href="javascript:void(0);" onclick="$('#deleteNetworkForm').submit();"> <i class="fa fa-trash-o fa-lg"></i> Delete ]]print(this_net) print[[</a> ]
   </form>]]
end

print[[<form id="l7ProtosForm" onsubmit="return checkShapedProtosFormCallback();" method="post">
   <input type="hidden" name="proto_network" value="]] print(net) print[[">
   <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
]]

local protos = interface.getnDPIProtocols()
local protos_in_use = shaper_utils.getNetworkProtoShapers(ifid, net, true --[[ do not aggregate into categories ]])
local protocol_categories = shaper_utils.getCategoriesWithProtocols()

-- families of protocols which are currently used by at least one protocol
local categories_in_use = {}
for k,v in pairs(protos_in_use) do
   local proto_id = tonumber(v.protoId)

   -- can be null for default
   if proto_id ~= nil then
      local category_id = tostring(interface.getnDPIProtoCategory(proto_id).id)
      if not categories_in_use[category_id] then
         categories_in_use[category_id] = 1
      else
         categories_in_use[category_id] = categories_in_use[category_id] + 1
      end
   end
end

function print_ndpi_families_and_protocols(categories, protos, categories_disabled, protos_disabled, terminator)
   local protos_excluded = {GRE=1, BGP=1, IGMP=1, IPP=1, IP_in_IP=1, OSPF=1, PPTP=1, SCTP=1, TFTP=1}

   print('<optgroup label="'..i18n("shaping.protocol_families")..'">')
   for k,category in pairsByKeys(categories, asc) do
      print('<option value="cat_'..category.id..'"')
      if categories_disabled[category.id] ~= nil then print(' disabled="disabled"') end
      print('>' .. k .. " " .. ' ('.. category.count .. ')</option>'..terminator)
   end
   print('</optgroup>')

   print('<optgroup label="'..i18n("shaping.protocols")..'">')
   for protoName,protoId in pairsByKeys(protos, asc) do
      if not protos_excluded[protoName] then
         -- find protocol category
         for _,category in pairs(categories) do
            for _,catProto in pairs(category.protos) do
               if catProto == protoId then
                  print('<option value="'..protoId..'" data-category="'..category.id..'"')
                  if((protos_disabled[protoName]) or (protos_disabled[protoId])) then
                     print(' disabled="disabled"')
                  end
                  print(">"..protoName.."</option>"..terminator)
                  break
               end
            end
         end
      end
   end
   print('</optgroup>')
end

   print [[<div id="table-protos"></div>
<button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
</form></td></tr>
</table>

NOTES:
<ul>
<li>Dropping some core protocols can have side effects on other protocols. For instance if you block DNS,<br>symbolic host names are no longer resolved, and thus only communication with numeric IPs work.
</ul>



<script>
function makeShapersDropdownCallback(suffix, ingress_shaper_idx, egress_shaper_idx) {
   var ingress_shaper = $("td:nth-child("+ingress_shaper_idx+")", $(this));
   var egress_shaper = $("td:nth-child("+egress_shaper_idx+")", $(this));
   var ingress_shaper_id = ingress_shaper.html();
   var egress_shaper_id = egress_shaper.html();

   ingress_shaper.html('<select class="form-control shaper-selector" name="ishaper_'+suffix+'">]] print_shapers(shapers, "", "\\\n") print[[</select>');
   egress_shaper.html('<select class="form-control shaper-selector" name="eshaper_'+suffix+'">]] print_shapers(shapers, "", "\\\n") print[[</select>');

   /* Select the current value */
   $("select", ingress_shaper).val(ingress_shaper_id);
   $("select", egress_shaper).val(egress_shaper_id);
}

/* -------------------------------------------------------------------------- */

function checkNetworksFormCallback() {
   var new_net_field = "#" + getNetworkInputField();
   var new_net_name = $(new_net_field).val();

   if (new_net_name) {
      /* we are adding a new network */
      if (! validateAddNetworkForm(new_net_field, "#new_vlan"))
         return false;

      // newtwork is valid here, now fill in the real form
      var netkey = new_net_name + "@" +  $("#new_vlan").val();
      var params = {};
      params["network"] = netkey;
      params["ishaper_" + netkey] = 0;
      params["eshaper_" + netkey] = 0;
      if ($("#clone_from_select").attr("name") == "clone")
         params["clone"] = $("#clone_from_select").find(":selected").val();

      // encode parameters since networks could contain special characters
      var encoded_params = paramsPairsEncode(params);
      $("#editNetworksForm").attr("action", "?page=filtering&network=" + netkey + "#protocols");
      paramsToForm("#editNetworksForm", encoded_params).submit();
   }

   return false;
}

function toggleCustomNetworkMode() {
   var n_custom = document.getElementById("new_custom_network");
   var n_local = document.getElementById("new_network");
   var custom_mode = (n_custom.style.display != "none");

   if (custom_mode) {
      n_custom.style.display = "none";
      n_local.style.display = "inline";
   } else {
      n_custom.style.display = "inline";
      n_custom.value = n_local.value;
      n_local.style.display = "none";
   }
}

   $("#proto_network").change(function() {
      document.location.href = "]] print(ntop.getHttpPrefix()) print [[/lua/if_stats.lua?page=filtering&network="+$("#proto_network").val()+"#protocols";
   });

   $("#clone_proto_policy button").click(function () {
      var active;
      var inactive;
      if ($(this).val() == "empty") {
         active = "#bt_initial_empty";
         inactive = "#bt_initial_clone";
         $("#clone_from_select").removeAttr("name");
         $("#clone_from_container").css("visibility", "hidden");
      } else {
         active = "#bt_initial_clone";
         inactive = "#bt_initial_empty";
         $("#clone_from_select").attr("name", "clone");
         $("#clone_from_container").css("visibility", "visible");
      }
      $(active)
         .removeClass("btn-default")
         .addClass("active")
         .addClass("btn-primary");
      $(inactive)
         .addClass("btn-default")
         .removeClass("active")
         .removeClass("btn-primary");
   });

   if (typeof add_new_network_at_startup != "undefined") {
      var s = add_new_network_at_startup.split("@");
      if (s.length == 2) {
         // put an initial custom network and vlan
         toggleCustomNetworkMode();
         $("#new_custom_network").val(s[0]);
         $("#new_vlan").val(s[1]);
      }
   }

   function checkShapedProtosFormCallback() {
      var new_protos = $("#table-protos select[name='new_protocol_id']").closest('tr');

      new_protos.each(function() {
         var new_proto = $(this);
         var td_proto = $("td:nth-child(1)", new_proto);
         var td_ingress_shaper = $("td:nth-child(2)", new_proto);
         var td_egress_shaper = $("td:nth-child(3)", new_proto);

         var selected = $("option:selected", td_proto);
         var proto_id = selected.val();

         /* set form fields names to match datatable generated ones */
         $("select", td_proto).attr('name', '');
         $("select", td_ingress_shaper).attr('name', 'ishaper_'+proto_id);
         $("select", td_egress_shaper).attr('name', 'eshaper_'+proto_id);
      });

      return true;
   }

   var new_row_ctr = 0;
   var protocol_categories = ]] print(json.encode(protocol_categories)) print[[;

   function addNewShapedProto() {
      var newid_prefix = "new_added_row_"
      var newid = newid_prefix + new_row_ctr;
      new_row_ctr += 1;

      var tr = $('<tr id="' + newid + '" ><td><select class="form-control" name="new_protocol_id">\
            ]] print_ndpi_families_and_protocols(protocol_categories, protos, categories_in_use, protos_in_use, "\\") print[[
      </select></td><td class="text-center"><select class="form-control shaper-selector" name="ingress_shaper_id">\
]] print_shapers(shapers, "0", "\\") print[[
      </select></td><td class="text-center"><select class="form-control shaper-selector" name="egress_shaper_id">\
]] print_shapers(shapers, "0", "\\") print[[
         </optgroup>\
      </select></td><td class="text-center" style="vertical-align: middle;"></td></tr>');

      $("#table-protos table").append(tr);
      datatableMakeSelectUnique(tr, newid_prefix, {
         on_change: function(select, old_val, new_val, others, change_fn) {

            function changeConditionally(option, to_enable) {
               if(! to_enable) {
                  if (! option.attr("disabled")) {
                     option.attr("data-auto-disabled", true);
                     change_fn(option, false);
                  }
               } else if (option.attr("data-auto-disabled")) {   // avoid to enable existing protocols
                  change_fn(option, true);
               }
            }

            function updateProtocols(category_id, to_enable) {
               $.each(protocol_categories, function(_, category) {
                  if(category.id == category_id) {
                     for (var proto_name in category.protos) {
                        var proto_id = category.protos[proto_name];
                        $.each(others, function(_, other) {
                           var option = other.find("option[value='" + proto_id + "']");
                           changeConditionally(option, to_enable);
                        });
                     }
                  }
               });
            }

            function updateCategories(protocol_id, to_enable) {
               var category_id = null;

               $.each(protocol_categories, function(_, category) {
                  for (var proto_name in category.protos) {
                     var proto_id = category.protos[proto_name];

                     if(proto_id == protocol_id) {
                        // category found
                        category_id = "cat_" + category.id;
                        break;
                     }
                  }
                  if (category_id != null)   return false;
               });

               if (category_id != null) {
                  $.each(others, function(_, other) {
                     var option = other.find("option[value='" + category_id + "']");
                     changeConditionally(option, to_enable);
                  });
               }
            }

            if (old_val.startsWith("cat_")) {
               // old value was a category, we must enable individual protocols
               var category_id = old_val.split("cat_")[1];
               updateProtocols(category_id, true);
            } else {
               // old value was a protocol, possibly enable its category
               updateCategories(old_val, true);
            }

            if (new_val.startsWith("cat_")) {
               // new value is a category, we must disable individual protocols
               var category_id = new_val.split("cat_")[1];
               updateProtocols(category_id, false);
            } else {
               // new value is a protocol, disable its category
               updateCategories(new_val, false);
            }
         }
      });
      datatableAddDeleteButtonCallback.bind(tr)(4, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("shaping.no_shapers_available")) print[[')", "]] print(i18n('undo')) print[[");
      aysRecheckForm('#l7ProtosForm');
   }

   function deleteShapedProtocol(proto_id) {
      var form = $("#deleteShapedProtocolForm");
      var todel = $("input[name='del_l7_proto']", form);

      todel.val(proto_id);
      form.submit();
   }

   $("#table-protos").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_l7_proto_policies.lua?ifid=]] print(ifid.."") print[[&network=]] print(net) print[[",
      showPagination: true,
      perPage: ]] print(perPageProtos) print[[,
      title: "",
      forceTable: true,
      buttons: [
         '<a id="addNewShapedProtoBtn" onclick="addNewShapedProto()" role="button" class="add-on btn" data-toggle="modal"><i class="fa fa-plus" aria-hidden="true"></i></a>'
      ], columns: [
         {
            title: "]] print(i18n("protocol")) print[[",
            field: "column_proto",
            css: {
               width: '15%',
               verticalAlign: 'middle'
            }
         }, {
            title: "]] print(i18n("shaping.traffic_to") .. " " .. this_net) print[[",
            field: "column_ingress_shaper",
            css: {
               width: '20%',
               textAlign: 'center',
               verticalAlign: 'middle'
            }
         }, {
            title: "]] print(i18n("shaping.traffic_from") .. " " .. this_net) print[[",
            field: "column_egress_shaper",
            css: {
               width: '20%',
               textAlign: 'center',
               verticalAlign: 'middle'
            }
         }, {
            title: "]] print(i18n("actions")) print[[",
            css : {
               width: '15%',
               textAlign: 'center',
               verticalAlign: 'middle'
            }
         }
      ], tableCallback: function() {
         var proto_id;

         datatableForEachRow("#table-protos", [
            function() {
               proto_id = $("td:nth-child(1) span", $(this)).attr("data-proto-id");
            }, function() {
               makeShapersDropdownCallback.bind(this)(proto_id, 2, 3);
            }, function() {
               if (proto_id != ']] print(shaper_utils.NETWORK_SHAPER_DEFAULT_PROTO_KEY) print[[')
                  datatableAddDeleteButtonCallback.bind(this)(4, "deleteShapedProtocol('" + proto_id + "')", "]] print(i18n('delete')) print[[");
            }
         ]);

         /* Only enable add button if we are in the last page */
         var lastpage = $("#dt-bottom-details .pagination li:nth-last-child(3)", $("#table-protos"));
         $("#addNewShapedProtoBtn").attr("disabled", (((lastpage.length == 1) && (lastpage.hasClass("active") == false))));

         aysResetForm('#l7ProtosForm');
      }
   });

   function validateAddNetworkForm(network_field_id, vlan_field_id) {
      var badnet_invalid_msg = "<strong>Warning</strong> Invalid VLAN/network specified.";
      var badnet_existing_msg = "<strong>Warning</strong> Specified VLAN/network policy exists.";
      var netval = $(network_field_id).val();

      if(is_network_mask(netval)) {
         var vlan= $(vlan_field_id).val();
         if((vlan >= 0) && (vlan <= 4095)) {
            var existing = false;
            var fullval = netval + "@" + vlan;

            var nets = [
]] for _,net in ipairs(nets) do
   print('"'..net..'",\n')
end;
print[[     ];
            existing = nets.indexOf(fullval) != -1;

            if (! existing) {
               $('#badnet').hide();
               $('input[name="new_network"]').val(netval);
               return true;
            } else {
               $('#badnet').html(badnet_existing_msg);
               $('#badnet').show();
               return false;
            }
         } else {
            $('#badnet').html(badnet_invalid_msg);
            $('#badnet').show();
            return false;
         }
      } else {
         //alert("Invalid network specified");
         $('#badnet').html(badnet_invalid_msg);
         $('#badnet').show();
         return false;
      }
   }

   function getNetworkInputField() {
      var n_custom = document.getElementById("new_custom_network");
      if (n_custom) {
         var custom_mode = (n_custom.style.display != "none");
         if (custom_mode)
            return "new_custom_network";
         else
            return "new_network";
      }
      return null;
   }
</script>
</table>
</div>
]]

-- ******************************************

-- ==== Bandwidth Manager tab ====

print[[
  <div id="shapers" class="tab-pane">
   <form id="deleteShaperForm" method="post">
      <input type="hidden" name="delete_shaper" value="">
      <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   </form>
   <form id="addShaperForm" method="post">
      <input type="hidden" name="add_shapers" value="">
      <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   </form>

   <form id="modifyShapersForm" method="post">
      <input type="hidden" name="add_shapers" value="">
      <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   <br/><div id="table-shapers"></div>

   <script>
]]

local rate_buttons = shaper_utils.rateButtons(1)
print(rate_buttons.init.."\n")

print[[
   var rate_buttons_code = ']] print(rate_buttons.js) print[[';

   function replaceCtrlId(v, shaper_id) {
      return v.replace(/\_\_\_CTRL\_ID\_\_\_/g, "shaper_max_rate_" + shaper_id);
   }

   function shaperRateTextField(td_object, shaper_id, value) {
      // fix ctrl id
      var buttons = $(replaceCtrlId(td_object.html(), shaper_id));
      var div = $('<div class="text-center form-group" style="padding:0 1em; margin:0;"></div>');
      td_object.html("");
      div.appendTo(td_object);
      buttons.appendTo(div);

      var input = $('<input name="shaper_' + shaper_id + '" class="form-control" type="number" data-min="-1" data-max="]] print(SHAPERS_MAX_RATE_KPBS.."") print[[" style="width:8em; text-align:right; margin-left:1em; display:inline;" required/>');
      input.val(value);
      input.appendTo(div);

      if ((shaper_id == ]] print(shaper_utils.DEFAULT_SHAPER_ID) print[[) ||
          (shaper_id == ]] print(shaper_utils.BLOCK_SHAPER_ID) print[[)) {
         input.attr("disabled", "disabled");
         buttons.find("label").attr("disabled", "disabled");
      }

      // execute group specific code
      eval(replaceCtrlId(rate_buttons_code, shaper_id));

      if((typeof shaper_just_added != "undefined") && (shaper_just_added == shaper_id))
         input.focus();
   }

   /* The next id to assign to new shapers */
   var nextShaperId = 2;

   function addNewShaper() {
      var shaperId = nextShaperId;

      var form_obj = $("#addShaperForm");
      form_obj.append($('<input type="hidden" name="shaper_' + shaperId + '" value="-1"/>'));
      form_obj.submit();

      /*tr_obj = $('<tr><td class="text-center">'+shaperId+'</td><td></td><td></td><td class="text-center"></td></tr>');
      $("#table-shapers tr:last").after(tr_obj);
      shaperRateTextField($("td:nth-child(2)", tr_obj), shaperId, -1);
      addShaperActionsToRow(tr_obj, shaperId);*/
   }

   function deleteShaper(shaper_id) {
      var form = $("#deleteShaperForm");
      var todel = $("input[name='delete_shaper']", form);

      todel.val(shaper_id);
      form.submit();
   }

   function addShaperActionsToRow(tr_obj, shaper_id) {
      if ((shaper_id != ]] print(shaper_utils.DEFAULT_SHAPER_ID) print[[) && (shaper_id != ]] print(shaper_utils.BLOCK_SHAPER_ID) print[[)) {
         var td_obj = $("td:nth-child(4)", tr_obj);
         td_obj.html('<a href="javascript:void(0)" class="add-on btn" onclick="deleteShaper(' + shaper_id + ')" role="button"><span class="label label-danger">Delete</span></a>');

         var applied_to = $("td:nth-child(3)", tr_obj);
         if (applied_to.html() != "&nbsp;")
            // this shaper is in use
            $("a", td_obj).attr("disabled", "disabled");
      }
   }

   $("#table-shapers").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_shapers.lua?ifid=]] print(ifid.."") print[[",
      title: "",
      hidePerPage: true,
      perPage: ]] print(shaper_utils.MAX_NUM_SHAPERS) print[[,
      buttons: [
         '<a id="addNewShaperBtn" onclick="addNewShaper()" role="button" class="add-on btn" data-toggle="modal"><i class="fa fa-plus" aria-hidden="true"></i></a>'
      ], columns: [
         {
            title: "]] print(i18n("shaping.shaper_id")) print[[",
            field: "column_shaper_id",
            css: {
               textAlign: 'center',
               width: '10%',
               verticalAlign: 'middle'
            }
         }, {
            title: "]] print(i18n("max_rate")) print[[",
            field: "column_max_rate",
            css : {
               width: '25em',
               verticalAlign: 'middle'
            }
         }, {
            title: "]] print(i18n("shaping.applied_to")) print[[",
            field: "column_used_by",
            css : {
               verticalAlign: 'middle'
            }
         }, {
            title: "]] print(i18n("actions")) print[[",
            css : {
               width: '10%',
               textAlign: 'center',
               verticalAlign: 'middle'
            }
         }
      ], tableCallback: function() {
         /* Make max rate editable */
         datatableForEachRow("#table-shapers", function() {
            var shaper_id = $("td:nth-child(1)", $(this)).html();
            var max_rate = $("td:nth-child(2)", $(this));

            var rate_input = max_rate.find("input[name='shaper_rate']");
            rate_input.remove();
            shaperRateTextField(max_rate, shaper_id, rate_input.val());

            addShaperActionsToRow($(this), shaper_id);
         });

         /* pick the first unused shaper ID */
         $("#table-shapers td:nth-child(1)").each(function() {
            var this_shaper_id = parseInt($(this).html());
            if(nextShaperId == this_shaper_id)
               nextShaperId += 1;
         });

         $("#table-shapers > div:last").append('<button class="btn btn-primary btn-block" style="width:30%; margin:1em auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>')

         var num_shapers = $('#table-shapers tr').length - 1;
         $("#addNewShaperBtn").attr("disabled", num_shapers >= ]] print(shaper_utils.MAX_NUM_SHAPERS) print[[);

         aysResetForm('#modifyShapersForm');
      }
   });
</script>]]

print [[</form>
  ]] print(i18n('shaping.notes')) print[[
<ul>
<li>]] print(i18n('shaping.shaper0_message')) print[[</li>
<li>]] print(i18n('shaping.shapers_in_use_message')) print[[</li>
<li>]] print(i18n('shaping.set_max_rate_to')) print[[<ul>
   <li>-1 ]] print(i18n('shaping.for_no_shaping')) print[[</li>
   <li>0 ]] print(i18n('shaping.for_dropping_all_traffic')) print[[</li>
</ul></li>
</ul>
</div>

<script>
   /*** Page Tab State ***/
   $('#filterPageTabPanel a').click(function(e) {
     e.preventDefault();
   });

   // store the currently selected tab in the hash value
   $("ul.nav-tabs > li > a").on("shown.bs.tab", function(e) {
      var id = $(e.target).attr("href").substr(1);
      if(history.replaceState) {
         // this will prevent the 'jump' to the hash
         history.replaceState(null, null, "#"+id);
      } else {
         // fallback
         window.location.hash = id;
      }
   });

   // on load of the page: switch to the currently selected tab
   var hash = window.location.hash;
   if (! hash) hash = "#protocols";
   $('#filterPageTabPanel a[href="' + hash + '"]').tab('show');
   /*** End Page Tab State ***/

   aysHandleForm("form", {
      handle_datatable: true,
      handle_tabs: true,
      ays_options: {addRemoveFieldsMarksDirty: true}
   });
</script>
]]

elseif page == "traffic_report" then
   dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/traffic_report.lua")
end

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
   print("var a_to_b_last_num_pkts_send_buffer_full  = " .. ifstats["bridge.a_to_b.num_pkts_send_buffer_full"] .. ";\n")
   print("var a_to_b_last_num_pkts_send_error  = " .. ifstats["bridge.a_to_b.num_pkts_send_error"] .. ";\n")

   print("var b_to_a_last_in_pkts  = " .. ifstats["bridge.b_to_a.in_pkts"] .. ";\n")
   print("var b_to_a_last_out_pkts  = " .. ifstats["bridge.b_to_a.out_pkts"] .. ";\n")
   print("var b_to_a_last_in_bytes  = " .. ifstats["bridge.b_to_a.in_bytes"] .. ";\n")
   print("var b_to_a_last_out_bytes  = " .. ifstats["bridge.b_to_a.out_bytes"] .. ";\n")
   print("var b_to_a_last_filtered_pkts  = " .. ifstats["bridge.b_to_a.filtered_pkts"] .. ";\n")
   print("var b_to_a_last_num_pkts_send_buffer_full  = " .. ifstats["bridge.b_to_a.num_pkts_send_buffer_full"] .. ";\n")
   print("var b_to_a_last_num_pkts_send_error  = " .. ifstats["bridge.b_to_a.num_pkts_send_error"] .. ";\n")
end

if(ifstats.zmqRecvStats ~= nil) then
   print("var last_zmq_time = 0;\n")
   print("var last_zmq_flows = ".. ifstats.zmqRecvStats.flows .. ";\n")
   print("var last_zmq_events = ".. ifstats.zmqRecvStats.events .. ";\n")
   print("var last_zmq_counters = ".. ifstats.zmqRecvStats.counters .. ";\n")
   print("var last_zmq_msg_drops = ".. ifstats.zmqRecvStats.zmq_msg_drops .. ";\n")
end

print [[

var resetInterfaceCounters = function(drops_only) {
  var action = "reset_all";
  if(drops_only) action = "reset_drops";
  $.ajax({ type: 'post',
    url: ']]
print (ntop.getHttpPrefix())
print [[/lua/reset_stats.lua',
    data: 'action=' + action + "&csrf=]] print(ntop.getRandomCSRFValue()) print[[",
    success: function(rsp) {},
    complete: function() {
      /* reload the page to generate a new CSRF */
      window.location.href = window.location.href;
    }
  });
}

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
           $('#if_zmq_msg_drops').html(addCommas(rsp.zmqRecvStats.zmq_msg_drops)+" "+get_trend(rsp.zmqRecvStats.zmq_msg_drops, last_zmq_msg_drops));

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

	if((rsp.packets + rsp.drops) > 0) {
          pctg = ((rsp.drops*100)/(rsp.packets+rsp.drops)).toFixed(2);
        }
	if(rsp.drops > 0) {
          drops = '<span class="label label-danger">';
        }
	drops = drops + addCommas(rsp.drops)+" ]]

print("Pkts")
print [[";

	if(pctg > 0)      { drops  += " [ "+pctg+" % ]"; }
	if(rsp.drops > 0) { drops  += '</span>'; }
	$('#if_drops').html(drops);

        $('#exported_flows').html(fint(rsp.flow_export_count));
        $('#exported_flows_rate').html(Math.round(rsp.flow_export_rate * 100) / 100);
        if(rsp.flow_export_drops > 0) {
          $('#exported_flows_drops')
            .addClass("label label-danger")
            .html(fint(rsp.flow_export_drops));
          if(rsp.flow_export_count > 0) {
            $('#exported_flows_drops_pct')
              .addClass("label label-danger")
              .html("[" + Math.round(rsp.flow_export_drops / rsp.flow_export_count * 100 * 1000) / 1000 + "%]");
          } else {
            /* If rsp.flow_export_count means that only drops have been occuring so it is meaningless to print a pct */
            $('#exported_flows_drops_pct').removeClass().html("");
          }
        } else {
          $('#exported_flows_drops').removeClass().html("0");
          $('#exported_flows_drops_pct').removeClass().html("[0%]");
        }

        var btn_disabled = true;
	if(rsp.drops + rsp.bytes + rsp.packets + rsp.flow_export_count + rsp.flow_export_drops > 0) {
          btn_disabled = false;
          $('#btn_reset_all').removeClass("disabled");
        }
        $('#btn_reset_all').disable(btn_disabled);

        btn_disabled = true;
	if(rsp.drops + rsp.flow_export_drops == 0) {
          btn_disabled = false;
          $('#btn_reset_drops').removeClass("disabled");
        }
        $('#btn_reset_drops').disable(btn_disabled);

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
   $('#b_to_a_num_pkts_send_error').html(addCommas(rsp["b_to_a_num_pkts_send_error"])+" Pkts "+get_trend(b_to_a_last_num_pkts_send_error, rsp["b_to_a_num_pkts_send_error"]));
   $('#b_to_a_num_pkts_send_buffer_full').html(addCommas(rsp["b_to_a_num_pkts_send_buffer_full"])+" Pkts "+get_trend(b_to_a_last_num_pkts_send_buffer_full, rsp["b_to_a_num_pkts_send_buffer_full"]));

   a_to_b_last_in_pkts = rsp["a_to_b_in_pkts"];
   a_to_b_last_out_pkts = rsp["a_to_b_out_pkts"];
   a_to_b_last_in_bytes = rsp["a_to_b_in_bytes"];
   a_to_b_last_out_bytes = rsp["a_to_b_out_bytes"];
   a_to_b_last_filtered_pkts = rsp["a_to_b_filtered_pkts"];
   a_to_b_last_num_pkts_send_buffer_full = rsp["a_to_b_num_pkts_send_buffer_full"];
   a_to_b_last_num_pkts_send_error = rsp["a_to_b_num_pkts_send_error"];

   b_to_a_last_in_pkts = rsp["b_to_a_in_pkts"];
   b_to_a_last_out_pkts = rsp["b_to_a_out_pkts"];
   b_to_a_last_in_bytes = rsp["b_to_a_in_bytes"];
   b_to_a_last_out_bytes = rsp["b_to_a_out_bytes"];
   b_to_a_last_filtered_pkts = rsp["b_to_a_filtered_pkts"];
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

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
