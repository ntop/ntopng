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
   require "snmp_utils"
end

local json = require "dkjson"
local host_pools_utils = require "host_pools_utils"
local template = require "template_utils"

require "lua_utils"
require "prefs_utils"
require "graph_utils"
require "alert_utils"
require "db_utils"

if ntop.isPro() then
   shaper_utils = require("shaper_utils")
end

local show_bridge_wizard = false

sendHTTPContentTypeHeader('text/html')

page = _GET["page"]
ifid = _GET["ifid"]

ifname_clean = "iface_"..tostring(ifid)
msg = ""

function inline_input_form(name, placeholder, tooltip, value, can_edit, input_opts, input_class)
   print [[<form class="form-inline" style="margin-bottom: 0px;" method="post">]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

   if(can_edit) then
      print('<input style="width:12em;" title="'..tooltip..'" '..(input_opts or "")..' class="form-control '..(input_class or "")..'" name="'..name..'" placeholder="'..placeholder..'" value="')
      if(value ~= nil) then print(value.."") end
      print[[">&nbsp;</input>&nbsp;<button type="submit" class="btn btn-default btn">]] print(i18n("save")) print[[</button>]]
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

   msg = "<div class=\"alert alert-success\">" .. i18n("if_stats_overview.iface_switch_active_msg", {interface=getHumanReadableInterfaceName(ifname), ifid=ifid}) .. "</div>"

   ntop.setCache(getRedisPrefix("ntopng.prefs")..'.iface', ifid)
else
   msg = "<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("if_stats_overview.iface_switch_error_msg") .. "</div>"
if(_SESSION["session"] == nil) then
   msg = msg .."<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("if_stats_overview.iface_switch_empty_session_msg") .. "</div>"
end
end
end

-- parse interface names and possibly fall back to the selected interface:
-- priority goes to the interface id
if ifid ~= nil and ifid ~= "" then
   if_name = getInterfaceName(ifid)
else
   -- fall-back to the default interface
   if_name = ifname
   ifid = interface.name2id(ifname)
end

interface.select(ifname)

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

   if(_POST["ifSpeed"] ~= nil) then
      local ifspeed_cache = 'ntopng.prefs.'..ifstats.name..'.speed'
      if isEmptyString(_POST["ifSpeed"]) then
         ntop.delCache(ifspeed_cache)
      else
         ntop.setCache(ifspeed_cache, _POST["ifSpeed"])
      end
   end

   if(_POST["ifRate"] ~= nil) then
      setInterfaceRegreshRate(ifstats.id, tonumber(_POST["ifRate"]))
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

url = ntop.getHttpPrefix()..'/lua/if_stats.lua?ifid=' .. ifid

--  Added global javascript variable, in order to disable the refresh of pie chart in case
--  of historical interface
print('\n<script>var refresh = '..getInterfaceRefreshRate(ifstats.id)..' * 1000; /* ms */;</script>\n')

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]

short_name = getHumanReadableInterfaceName(ifname)

if(short_name ~= if_name) then
   short_name = short_name .. "..."
end

print("<li><a href=\"#\">" .. i18n("interface") .. ": " .. short_name .."</a></li>\n")

if((page == "overview") or (page == nil)) then
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i></a></li>\n")
else
   print("<li><a href=\""..url.."&page=overview\"><i class=\"fa fa-home fa-lg\"></i></a></li>")
end

-- Disable Packets and Protocols tab in case of the number of packets is equal to 0
if((ifstats ~= nil) and (ifstats.stats.packets > 0)) then
   if(page == "packets") then
      print("<li class=\"active\"><a href=\"#\">" .. i18n("packets") .. "</a></li>\n")
   else
      print("<li><a href=\""..url.."&page=packets\">" .. i18n("packets") .. "</a></li>")
   end

   if(page == "ndpi") then
      print("<li class=\"active\"><a href=\"#\">" .. i18n("protocols") .. "</a></li>\n")
   else
      print("<li><a href=\""..url.."&page=ndpi\">" .. i18n("protocols") .. "</a></li>")
   end
end

if(page == "ICMP") then
  print("<li class=\"active\"><a href=\"#\">" .. i18n("icmp") .. "</a></li>\n")
else
  print("<li><a href=\""..url.."&page=ICMP\">" .. i18n("icmp") .. "</a></li>")
end

-- only show if the interface has seen mac addresses
if ifstats["has_macs"] then
   if(page == "ARP") then
     print("<li class=\"active\"><a href=\"#\">" .. i18n("arp") .. "</a></li>\n")
   else
     print("<li><a href=\""..url.."&page=ARP\">" .. i18n("arp") .. "</a></li>")
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

if(isAdministrator() and areAlertsEnabled()) then
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

if isAdministrator() and (not ifstats.isView) then
   if(page == "pools") then
      print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-users\"></i></a></li>\n")
   else
      print("\n<li><a href=\""..url.."&page=pools\"><i class=\"fa fa-users\"></i></a></li>")
   end
end

if(hasSnmpDevices(ifstats.id) and is_packet_interface and false --[[disabled: no functionality provided right now]]) then
   if(page == "snmp_bind") then
      print("\n<li class=\"active\"><a href=\"#\">" .. i18n("if_stats_overview.snmp") .. "</li>")
   else
      print("\n<li><a href=\""..url.."&page=snmp_bind\">" .. i18n("if_stats_overview.snmp") .. "</a></li>")
   end
end

if(ifstats.inline and isAdministrator()) then
   if(page == "filtering") then
      print("<li class=\"active\"><a href=\""..url.."&page=filtering\">"..i18n('traffic_policy').."</a></li>")
   else
      print("<li><a href=\""..url.."&page=filtering\">"..i18n('traffic_policy').."</a></li>")
   end
end

local ifname_clean = "iface_"..tostring(ifid)

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>

   ]]

if((page == "overview") or (page == nil)) then
   print("<table class=\"table table-striped table-bordered\">\n")
   print("<tr><th width=15%>"..i18n("if_stats_overview.id").."</th><td colspan=6>" .. ifstats.id .. " ")
   if(ifstats.description ~= ifstats.name) then print(" ("..ifstats.description..")") end
   print("</td></tr>\n")

   if interface.isPcapDumpInterface() == false then
      print("<tr><th width=250>"..i18n("if_stats_overview.state").."</th><td colspan=6>")
      state = toggleTableButton("", "", i18n("if_stats_overview.active"), "1","primary", i18n("if_stats_overview.paused"), "0","primary", "toggle_local", "ntopng.prefs."..if_name.."_not_idle")

      if(state == "0") then
	 on_state = true
      else
	 on_state = false
      end

      interface.setInterfaceIdleState(on_state)

      print("</td></tr>\n")
   end

   if(ifstats["remote.name"] ~= nil) then

      local remote_if_addr, remote_probe_ip, remote_probe_public_ip = '', '', ''

      if not isEmptyString(ifstats["remote.if_addr"]) then
	 remote_if_addr = "<b>"..i18n("if_stats_overview.interface_ip").."</b>: "..ifstats["remote.if_addr"]
      end

      if not isEmptyString(ifstats["probe.ip"]) then
	 remote_probe_ip = "<b>"..i18n("if_stats_overview.probe_ip").."</b>: "..ifstats["probe.ip"]
      end

      if not isEmptyString(ifstats["probe.public_ip"]) then
         remote_probe_public_ip = "<b>"..i18n("if_stats_overview.public_probe_ip").."</b>: <A HREF=\"http://"..ifstats["probe.public_ip"].."\">"..ifstats["probe.public_ip"].."</A> <i class='fa fa-external-link'></i></td>\n"
      end

      print("<tr><th rowspan=2>"..i18n("if_stats_overview.remote_probe").."</th><td nowrap><b>"..i18n("if_stats_overview.interface_name").."</b>: "..ifstats["remote.name"].." [ ".. maxRateToString(ifstats.speed*1000) .." ]</td>")
      print("<td nowrap>"..remote_if_addr.."</td>")
      print("<td nowrap>"..remote_probe_ip.."</td>")
      print("<td nowrap colspan=2>"..remote_probe_public_ip.."</td>\n")
      print("</tr>\n")

      print("<tr>")
      print("<td nowrap><b>"..i18n("if_stats_overview.probe_timeout_lifetime").."</b>: "..secondsToTime(ifstats["timeout.lifetime"]).."</td>")
      print("<td nowrap><b>"..i18n("if_stats_overview.probe_timeout_idle").."</b>: "..secondsToTime(ifstats["timeout.idle"]).."</td>")
      print("<td></td><td></td></tr>")
   end

   local is_physical_iface = (interface.isPacketInterface()) and (interface.isPcapDumpInterface() == false)
   local is_bridge_iface = (ifstats["bridge.device_a"] ~= nil) and (ifstats["bridge.device_b"] ~= nil)

   if not is_bridge_iface then
      local label = getInterfaceNameAlias(ifstats.name)
      local s
      if ((not isEmptyString(label)) and (label ~= ifstats.name)) then
         s = label .. " (" .. ifstats.name .. ")"
      else
         s = ifstats.name
      end

      if((isAdministrator()) and (interface.isPcapDumpInterface() == false)) then
	 s = s .. " <a href=\""..url.."&page=config\"><i class=\"fa fa-cog fa-sm\" title=\"Configure Interface Name\"></i></a>"
      end
      
      print('<tr><th width="250">'..i18n("name")..'</th><td colspan="2">' .. s ..' </td>\n')
   else
      print("<tr><th>"..i18n("bridge").."</th><td colspan=2>"..ifstats["bridge.device_a"].." <i class=\"fa fa-arrows-h\"></i> "..ifstats["bridge.device_b"])

      if(user_group == "administrator") and isBridgeInterface(ifstats) and ntop.isEnterprise() then
         print[[ <a href="#bridgeWizardModal" data-toggle="modal"><i class="fa fa-sm fa-magic" aria-hidden="true" title=]] print('\"'..i18n("bridge_wizard.bridge_wizard")..'\"') print[[></i></a>]]
         show_bridge_wizard = true
      end

      print("</td>")
   end

   print("<th>"..i18n("if_stats_overview.family").."</th><td colspan=2>")
   print(ifstats.type)

   if(ifstats.inline) then
      print(" "..i18n("if_stats_overview.in_path_interface"))
   end
   print("</tr>")

   if not is_bridge_iface then
      if(ifstats.ip_addresses ~= "") then
         tokens = split(ifstats.ip_addresses, ",")
      end

      if(tokens ~= nil) then
         print("<tr><th width=250>"..i18n("ip_address").."</th><td colspan=5>")
         local addresses = {}

         for _,s in pairs(tokens) do
            t = string.split(s, "/")
            host = interface.getHostInfo(t[1])

            if(host ~= nil) then
               addresses[#addresses+1] = "<a href=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..t[1].."\">".. t[1].."</a>"
            else
               addresses[#addresses+1] = t[1]
            end
         end

         print(table.concat(addresses, ", "))

         print("</td></tr>")
      end
   end

   if is_physical_iface then
      print("<tr>")
      print("<th>"..i18n("mtu").."</th><td colspan=2  nowrap>"..ifstats.mtu.." "..i18n("bytes").."</td>\n")
      if (not is_bridge_iface) then
         local speed_key = 'ntopng.prefs.'..ifname..'.speed'
         local speed = ntop.getCache(speed_key)
         if (tonumber(speed) == nil) then
            speed = ifstats.speed
         end
         print("<th width=250>"..i18n("speed").."</th><td colspan=2>" .. maxRateToString(speed*1000) .. "</td>")
      else
         print("<td colspan=3></td></tr>")
      end
      print("</tr>")
   end

   if(ifstats["pkt_dumper"] ~= nil) then
      print("<tr><th rowspan=2>"..i18n("if_stats_overview.packet_dumper").."</th><th colspan=2>"..i18n("if_stats_overview.dumped_packets").."</th><th colspan=2>"..i18n("if_stats_overview.dumped_files").."</th></tr>\n")
      print("<tr><td colspan=2><div id=dumped_pkts>".. formatValue(ifstats["pkt_dumper"]["num_dumped_pkts"]) .."</div></td>")
      print("<td colspan=2><div id=dumped_files>".. formatValue(ifstats["pkt_dumper"]["num_dumped_files"]) .."</div></td></tr>\n")
   end

   label = i18n("pkts")

   print[[ <tr><th colspan=1 nowrap>]] print(i18n("if_stats_overview.traffic_breakdown")) print[[</th> ]]

   if(ifstats.type ~= "zmq") then
      print [[ <td colspan=2><div class="pie-chart" id="ifaceTrafficBreakdown"></div></td><td colspan=3> <div class="pie-chart" id="ifaceTrafficDistribution"></div></td></tr> ]]
   else
      print [[ <td colspan=5><div class="pie-chart" id="ifaceTrafficBreakdown"></div></td></tr> ]]
   end

print [[
	<script type='text/javascript'>
	       window.onload=function() {
				   do_pie("#ifaceTrafficBreakdown", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_local_stats.lua', { ifid: ]] print(ifstats.id .. " }, \"\", refresh); \n")

if(ifstats.type ~= "zmq") then
print [[				   do_pie("#ifaceTrafficDistribution", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_local_stats.lua', { ifid: ]] print(ifstats.id .. ", iflocalstat_mode: \"distribution\" }, \"\", refresh); \n")
end
print [[ }

]]
print("</script>\n")

   if(ifstats.zmqRecvStats ~= nil) then
   print("<tr><th colspan=7 nowrap>"..i18n("if_stats_overview.zmq_rx_statistics").."</th></tr>\n")
   print("<tr><th nowrap>"..i18n("if_stats_overview.collected_flows").."</th><td width=20%><span id=if_zmq_flows>"..formatValue(ifstats.zmqRecvStats.flows).."</span>")
   print("<th nowrap>"..i18n("if_stats_overview.interface_rx_updates").."</th><td width=20%><span id=if_zmq_events>"..formatValue(ifstats.zmqRecvStats.events).."</span>")
   -- print("<th nowrap>"..i18n("if_stats_overview.sflow_counter_updates").."</th><td width=20%><span id=if_zmq_counters>"..formatValue(ifstats.zmqRecvStats.counters).."</span></tr>")
   print("<th nowrap>"..i18n("if_stats_overview.zmq_message_drops").."</th><td width=20%><span id=if_zmq_msg_drops>"..formatValue(ifstats.zmqRecvStats.zmq_msg_drops).."</span></tr>")
   end

   print("<tr><th colspan=7 nowrap>"..i18n("if_stats_overview.ingress_traffic").."</th></tr>\n")
   print("<tr><th nowrap>"..i18n("if_stats_overview.received_traffic").."</th><td width=20%><span id=if_bytes>"..bytesToSize(ifstats.stats.bytes).."</span> [<span id=if_pkts>".. formatValue(ifstats.stats.packets) .. " ".. label .."</span>] ")
   print("<span id=pkts_trend></span></td>")

   print("<th width=20%><span id='if_packet_drops_drop'><i class='fa fa-tint' aria-hidden='true'></i></span> ")

   print(i18n("if_stats_overview.dropped_packets").."</th>")

   print("<td width=20%><span id=if_drops>")

   if(ifstats.stats.drops > 0) then
      print('<span class="label label-danger">')
   end

   print(formatValue(ifstats.stats.drops).. " " .. label)

   if ifstats.stats.packets == null or ifstats.stats.drops == null then

   
   elseif((ifstats.stats.packets+ifstats.stats.drops) > 0) then
      local pctg = round((ifstats.stats.drops*100)/(ifstats.stats.packets+ifstats.stats.drops), 2)
      if(pctg > 0) then print(" [ " .. pctg .. " % ] ") end
   end

   if(ifstats.stats.drops > 0) then print('</span>') end
   print("</span>&nbsp;<span id=drops_trend></span>")
   if(ntop.getCache("ntopng.prefs.dynamic_iface_vlan_creation") == "1") then
      if(ifstats.type == "Dynamic VLAN") then
	 print("<br><small><b>"..i18n("if_stats_overview.note")..":</b> "..i18n("if_stats_overview.note_drop_ifstats_dynamic_vlan").."</small>")
      else
	 print("<br><small><b>"..i18n("if_stats_overview.note")..":</b> "..i18n("if_stats_overview.note_drop_ifstats_not_dynamic_vlan").."</small>")
      end
   end
   print("</td><td colspan=3>")
   print("</td></tr>\n")

   if(prefs.is_dump_flows_enabled and ifstats.isView == false) then
      local dump_to = "MySQL"
      if prefs.is_dump_flows_to_es_enabled == true then
	 dump_to = "ElasticSearch"
      end
      if prefs.is_dump_flows_to_ls_enabled == true then
	 dump_to = "Logstash"
      end

      local export_count     = ifstats.stats.flow_export_count
      local export_rate      = ifstats.stats.flow_export_rate
      local export_drops     = ifstats.stats.flow_export_drops
      local export_drops_pct = 0
      if export_drops == nill then 

      elseif export_drops > 0 and export_count > 0 then
	 export_drops_pct = export_drops / export_count * 100
      end

      print("<tr><th colspan=7 nowrap>"..dump_to.." "..i18n("if_stats_overview.flows_export_statistics").."</th></tr>\n")

      print("<tr>")
      print("<th nowrap>"..i18n("if_stats_overview.exported_flows").."</th>")
      print("<td><span id=exported_flows>"..formatValue(export_count).."</span>")
      if export_rate == nil then
	export_rate = 0
      end
      print("&nbsp;[<span id=exported_flows_rate>"..formatValue(round(export_rate, 2)).."</span> Flows/s]</td>")

      print("<th><span id='if_flow_drops_drop'<i class='fa fa-tint' aria-hidden='true'></i></span> ")
      print(i18n("if_stats_overview.dropped_flows").."</th>")

      local span_danger = ""
      if export_drops == nil then 

     
      elseif(export_drops > 0) then
	 span_danger = ' class="label label-danger"'
      end
      print("<td><span id=exported_flows_drops "..span_danger..">"..formatValue(export_drops).."</span>&nbsp;")
      print("<span id=exported_flows_drops_pct "..span_danger..">["
	       ..formatValue(round(export_drops_pct, 2)).."%]</span></td>")
      print("<td colspan=3>&nbsp;</td>")
      print("</tr>")
   end

   if (isAdministrator() and ifstats.isView == false) then
      print("<tr><th width=250>"..i18n("if_stats_overview.reset_counters").."</th>")
      print("<td colspan=5>")

      local cls = ""
      local tot	= ifstats.stats.bytes + ifstats.stats.packets + ifstats.stats.drops
      if(ifstats.stats.flow_export_count ~= nil) then
      	tot = tot + ifstats.stats.flow_export_count + ifstats.stats.flow_export_drops
      end
      
      if tot == 0 then
	 cls = " disabled"
      end
      print('<button id="btn_reset_all" type="button" class="btn btn-default btn-xs'..cls..'" onclick="resetInterfaceCounters(false);">'..i18n("if_stats_overview.all_counters")..'</button>&nbsp;')

      cls = ""
      if(ifstats.stats.flow_export_count ~= nil) then
        if ifstats.stats.drops + ifstats.stats.flow_export_drops == 0 then
	 cls = " disabled"
	end
      end
      print('<button id="btn_reset_drops" type="button" class="btn btn-default btn-xs'..cls..'" onclick="resetInterfaceCounters(true);">'..i18n("if_stats_overview.drops_only")..'</button>')
      print("</td>")

      print("</tr>\n")
   end

   if((ifstats["bridge.device_a"] ~= nil) and (ifstats["bridge.device_b"] ~= nil)) then
      print("<tr><th colspan=7>"..i18n("if_stats_overview.bridged_traffic").."</th></tr>\n")
      print("<tr><th nowrap>"..i18n("interface").."</th><th nowrap>"..i18n("if_stats_overview.ingress_packets").."</th><th nowrap>"..i18n("if_stats_overview.egress_packets").."</th><th nowrap>"..i18n("if_stats_overview.shaped_filtered_packets").."</th><th nowrap>"..i18n("if_stats_overview.send_error").."</th><th nowrap>"..i18n("if_stats_overview.buffer_full").."</th></tr>\n")
      print("<tr><th>".. ifstats["bridge.device_a"] .. "</th><td><span id=a_to_b_in_pkts>".. formatPackets(ifstats["bridge.a_to_b.in_pkts"]) .."</span> <span id=a_to_b_in_pps></span></td>")
      print("<td><span id=a_to_b_out_pkts>".. formatPackets(ifstats["bridge.a_to_b.out_pkts"]) .."</span> <span id=a_to_b_out_pps></span></td>")
      print("<td><span id=a_to_b_filtered_pkts>".. formatPackets(ifstats["bridge.a_to_b.filtered_pkts"]) .."</span></td>")

      print("<td><span id=a_to_b_num_pkts_send_error>".. formatPackets(ifstats["bridge.a_to_b.num_pkts_send_error"]) .."</span></td>")
      print("<td><span id=a_to_b_num_pkts_send_buffer_full>".. formatPackets(ifstats["bridge.a_to_b.num_pkts_send_buffer_full"]) .."</span></td>")

      print("</tr>\n")

      print("<tr><th>".. ifstats["bridge.device_b"] .. "</th><td><span id=b_to_a_in_pkts>".. formatPackets(ifstats["bridge.b_to_a.in_pkts"]) .."</span> <span id=b_to_a_in_pps></span></td>")
      print("<td><span id=b_to_a_out_pkts>"..formatPackets( ifstats["bridge.b_to_a.out_pkts"]) .."</span> <span id=b_to_a_out_pps></span></td>")

      print("<td><span id=b_to_a_filtered_pkts>".. formatPackets(ifstats["bridge.b_to_a.filtered_pkts"]) .."</span></td>")

      print("<td><span id=b_to_a_num_pkts_send_error>".. formatPackets(ifstats["bridge.b_to_a.num_pkts_send_error"]) .."</span></td>")
      print("<td><span id=b_to_a_num_pkts_send_buffer_full>".. formatPackets(ifstats["bridge.b_to_a.num_pkts_send_buffer_full"]) .."</span></td>")

      print("</tr>\n")
   end

   print [[
   <tr><td colspan=7> <small> <b>]] print(i18n("if_stats_overview.note").."</b>:<p>"..i18n("if_stats_overview.note_packets")) print[[</small> </td></tr>
   ]]

   print("</table>\n")

   if show_bridge_wizard then
      dofile(dirs.installdir .. "/scripts/lua/inc/bridge_wizard.lua")
   end
elseif((page == "packets")) then
   print [[ <table class="table table-bordered table-striped"> ]]
   print("<tr><th width=30% rowspan=3>" .. i18n("packets_page.tcp_packets_analysis") .. "</th><th>" .. i18n("packets_page.retransmissions") .."</th><td align=right><span id=pkt_retransmissions>".. formatPackets(ifstats.tcpPacketStats.retransmissions) .."</span> <span id=pkt_retransmissions_trend></span></td></tr>\n")
   print("<tr></th><th>" .. i18n("packets_page.out_of_order") .. "</th><td align=right><span id=pkt_ooo>".. formatPackets(ifstats.tcpPacketStats.out_of_order) .."</span> <span id=pkt_ooo_trend></span></td></tr>\n")
   print("<tr></th><th>" .. i18n("packets_page.lost") .. "</th><td align=right><span id=pkt_lost>".. formatPackets(ifstats.tcpPacketStats.lost) .."</span> <span id=pkt_lost_trend></span></td></tr>\n")

    if(ifstats.type ~= "zmq") then
      print [[<tr><th class="text-left">]] print(i18n("packets_page.size_distribution")) print [[</th><td colspan=5><div class="pie-chart" id="sizeDistro"></div></td></tr>]]
    end

    print[[
  	 <tr><th class="text-left">]] print(i18n("packets_page.tcp_flags_distribution")) print[[</th><td colspan=5><div class="pie-chart" id="flagsDistro"></div></td></tr>
    <tr><th class="text-left">]] print(i18n("packets_page.ip_version_distribution")) print[[</th><td colspan=5><div class="pie-chart" id="ipverDistro"></div></td></tr>
      </table>

	<script type='text/javascript'>
	 window.onload=function() {

       do_pie("#sizeDistro", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/if_pkt_distro.lua', { distr: "size", ifid: "]] print(ifstats.id.."\"")
   print [[
	   }, "", refresh);

       do_pie("#flagsDistro", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/if_tcpflags_pkt_distro.lua', { ifid: "]] print(ifstats.id.."\"")
   print [[
	   }, "", refresh);

      do_pie("#ipverDistro", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/if_pkt_distro.lua', { distr: "ipver", ifid: "]] print(ifstats.id.."\"")
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
      <tr><th class="text-left">]] print(i18n("ndpi_page.cumulative_protocol_stats")) print [[</th>
	       <td colspan=3><div class="pie-chart" id="topApplicationProtocols"></div></td>
	       <td colspan=2><div class="pie-chart" id="topApplicationBreeds"></div></td>
	       </tr>
      <tr><th class="text-left">]] print(i18n("ndpi_page.live_flows_count")) print [[</th>
	       <td colspan=3><div class="pie-chart" id="topFlowsCount"></div></td>
	       <td colspan=2><div class="pie-chart" id="topTCPFlowsStats"></div>
               <br><small><b>]] print(i18n("ndpi_page.note")) print [[ :</b>]] print(i18n("ndpi_page.note_live_flows_chart")) print [[
               </td>
	       </tr>
  </div>

	<script type='text/javascript'>
	 window.onload=function() {

       do_pie("#topApplicationProtocols", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_ndpi_stats.lua', { ndpistats_mode: "sinceStartup", ifid: "]] print(ifid) print [[" }, "", refresh);

       do_pie("#topApplicationBreeds", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_ndpi_stats.lua', { breed: "true", ndpistats_mode: "sinceStartup", ifid: "]] print(ifid) print [[" }, "", refresh);

       do_pie("#topFlowsCount", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_ndpi_stats.lua', { breed: "true", ndpistats_mode: "count", ifid: "]] print(ifid) print [[" }, "", refresh);

       do_pie("#topTCPFlowsStats", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_tcp_stats.lua', { ifid: "]] print(ifid) print [[" }, "", refresh);
    }

      </script><p>
  </table>
  ]]

   print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     ]]

   print("<thead><tr><th>" .. i18n("ndpi_page.application_protocol") .. "</th><th>" .. i18n("ndpi_page.total_since_startup") .. "</th><th>" .. i18n("percentage") .. "</th></tr></thead>\n")

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
    data: { ifid: "]] print(ifid) print [[" },
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

elseif(page == "ICMP") then

  print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     <thead><tr><th>]] print(i18n("icmp_page.icmp_message")) print [[</th><th style='text-align:right;'>]] print(i18n("traffic")) print[[</th></tr></thead>
     <tbody id="iface_details_icmp_tbody">
     </tbody>
     </table>

<script>
function update_icmp_table() {
  $.ajax({
    type: 'GET',
    url: ']]
  print(ntop.getHttpPrefix())
  print [[/lua/get_icmp_data.lua',
    data: { ifid: "]] print(ifId.."")  print [[" },
    success: function(content) {
      $('#iface_details_icmp_tbody').html(content);
      $('#myTable').trigger("update");
    }
  });
}

update_icmp_table();
setInterval(update_icmp_table, 5000);
</script>

]]
elseif(page == "ARP") then

  print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     <thead><tr><th>]] print(i18n("arp_page.arp_type")) print [[</th><th style='text-align:right;'>]] print(i18n("traffic")) print[[</th></tr></thead>
     <tbody id="iface_details_arp_tbody">
     </tbody>
     </table>

<script>
function update_arp_table() {
  $.ajax({
    type: 'GET',
    url: ']]
  print(ntop.getHttpPrefix())
  print [[/lua/get_arp_data.lua',
    data: { ifid: "]] print(ifId.."")  print [[" },
    success: function(content) {
      $('#iface_details_arp_tbody').html(content);
      $('#myTable').trigger("update");
    }
  });
}

update_arp_table();
setInterval(update_arp_table, 5000);
</script>

]]
   
elseif(page == "historical") then
   rrd_file = _GET["rrd_file"]
   selected_epoch = _GET["epoch"]
   if(selected_epoch == nil) then selected_epoch = "" end
   topArray = makeTopStatsScriptsArray()

   if(rrd_file == nil) then rrd_file = "bytes.rrd" end
   drawRRD(ifstats.id, nil, rrd_file, _GET["zoom"], url.."&page=historical", 1, _GET["epoch"], selected_epoch, topArray)
   --drawRRD(ifstats.id, nil, rrd_file, _GET["zoom"], url.."&page=historical", 1, _GET["epoch"], selected_epoch, topArray, _GET["comparison_period"])

   if ntop.isPro() then

      print[[

<br>

<div>
  <b>]] print(i18n('notes')) print[[</b>
  <ul>
    <li>]] print(i18n('graphs.note_click_to_zoom')) print[[</li>
    <li>]] print(i18n('graphs.note_protocols_shown')) print[[</li>
  </ul>
</div>

]]
   end

elseif(page == "trafficprofiles") then
   print("<table class=\"table table-striped table-bordered\">\n")
   print("<tr><th width=15%><a href=\""..ntop.getHttpPrefix().."/lua/pro/admin/edit_profiles.lua\">" .. i18n("traffic_profiles.profile_name") .. "</A></th><th width=5%>" .. i18n("chart") .. "</th><th>" .. i18n("traffic") .. "</th></tr>\n")
   for pname,pbytes in pairs(ifstats.profiles) do
     local trimmed = trimSpace(pname)
     local rrdname = fixPath(dirs.workingdir .. "/" .. ifid .. "/profilestats/" .. getPathFromKey(trimmed) .. "/bytes.rrd")
     local statschart_icon = ''
     if ntop.exists(rrdname) then
	 statschart_icon = '<A HREF=\"'..ntop.getHttpPrefix()..'/lua/profile_details.lua?profile='..trimmed..'\"><i class=\'fa fa-area-chart fa-lg\'></i></A>'
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
		    data: { iffilter: "]] print(tostring(interface.name2id(if_name))) print [[" },
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
}, ]] print(getInterfaceRefreshRate(ifstats.id).."") print[[ * 1000);

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

   print("<tr><th width=30%>" .. i18n("packetdump_page.packet_dump") .. "</th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	       print('<input type="hidden" name="dump_all_traffic" value="'..dump_all_traffic_value..'"><input type="checkbox" value="1" '..dump_all_traffic_checked..' onclick="this.form.submit();">'..' '..i18n("packetdump_page.dump_all_traffic"))
	       print('</input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%>" .. i18n("packetdump_page.packet_dump_to_disk").. "</th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	       print('<input type="hidden" name="dump_traffic_to_disk" value="'..dump_traffic_value..'"><input type="checkbox" value="1" '..dump_traffic_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> '..i18n("packetdump_page.dump_traffic_to_disk"))
	       if(dump_traffic_checked ~= "") then
		 dumped = interface.getInterfacePacketsDumpedFile()
	         print(" - " .. i18n("packetdump_page.num_dumped_packets",{num_pkts=ternary(dumped, dumped, 0)}))
	       end
	       print('</input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%></th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	       print('<input type="hidden" name="dump_unknown_to_disk" value="'..dump_unknown_value..'"><input type="checkbox" value="1" '..dump_unknown_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> '..i18n("packetdump_page.dump_unknown_traffic_to_disk")..' </input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%></th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	       print('<input type="hidden" name="dump_security_to_disk" value="'..dump_security_value..'"><input type="checkbox" value="1" '..dump_security_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> '..i18n("packetdump_page.dump_traffic_to_disk_on_security_alert")..' </input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   print("</td></tr>\n")

   print("<tr><th>" .. i18n("packetdump_page.packet_dump_to_tap") .. "</th><td>")
   if(interface.getInterfaceDumpTapName() ~= "") then
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">]]
	       print('<input type="hidden" name="dump_traffic_to_tap" value="'..dump_traffic_tap_value..'"><input type="checkbox" value="1" '..dump_traffic_tap_checked..' onclick="this.form.submit();"> <i class="fa fa-filter fa-lg"></i> '..i18n("packetdump_page.dump_traffic_to_tap")..' ')
	       print('('..interface.getInterfaceDumpTapName()..')')
	       if(dump_traffic_tap_checked ~= "") then
		 dumped = interface.getInterfacePacketsDumpedTap()
 		 print(" - " .. i18n("packetdump_page.num_dumped_packets",{num_pkts=ternary(dumped, dumped, 0)}))
	       end
	       print(' </input>')
	       print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	       print('</form>')
   else
      print(i18n("packetdump_page.packet_dump_to_tap_disabled_message"))
end

   print("</td></tr>\n")
   print("<tr><th width=250>"..i18n("packetdump_page.sampling_rate").."</th>\n")
   print [[<td>]]
   if(dump_security_checked ~= "") then
   print[[<form class="form-inline" style="margin-bottom: 0px;" method="post">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="sampling_rate" placeholder="" min="0" step="100" max="100000" value="]]
	 srate = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_sampling_rate')
	 if(srate ~= nil and srate ~= "" and srate ~= "0") then print(srate) else print("1000") end
	 print [["></input>
      &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">]] print(i18n("save")) print[[</button>
    </form>
<small> ]]
    print(i18n("packetdump_page.note") .. ": " .. i18n("packetdump_page.note_sampling_rate"))
print[[</small>]]
  else
    print(i18n("packetdump_page.sampling_rate_disabled_message"))
  end
  print[[
    </td></tr>
       ]]

   print("<tr><th colspan=2>" .. i18n("packetdump_page.dump_to_disk_parameters") .. "</th></tr>")
   print("<tr><th width=250>" .. i18n("packetdump_page.pcap_dump_directory") .. "</th><td>")
   pcapdir = dirs.workingdir .."/"..ifstats.id.."/pcap/"
   print(pcapdir.."</td></tr>\n")
   print("<tr><th width=250>" .. i18n("packetdump_page.max_packets_per_file") .. "</th>\n")
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
	 print [["></input> pkts &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">]] print(i18n("save")) print[[</button>
    </form>
    <small>]] print(i18n("packetdump_page.max_packets_per_file_description")) print [[</small>
    </td></tr>
       ]]
   print("<tr><th width=250>" .. i18n("packetdump_page.max_duration_file") .. "</th>\n")
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
		  &nbsp;sec &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">]] print(i18n("save")) print[[</button>
    </form>
    <small>]] print(i18n("packetdump_page.max_duration_file_description") .. "<br>") print(i18n("packetdump_page.note") .. ": " .. i18n("packetdump_page.note_max_duration_file")) print[[</small>
    </td></tr>
       ]]
   print("<tr><th width=250>" .. i18n("packetdump_page.max_size_dump_files") .. "</th>\n")
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
		  &nbsp; MB &nbsp;&nbsp;&nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">]] print(i18n("save")) print[[</button>
    </form>
    <small>]] print(i18n("packetdump_page.max_size_dump_files_description")) print[[<br>]] print(i18n("packetdump_page.note") .. ": " .. i18n("packetdump_page.note_max_size_dump_files")) print[[</small>
    </td></tr>
      ]]
   print("</table>")
end
elseif(page == "alerts") then

   drawAlertSourceSettings("interface", ifname_clean,
      i18n("show_alerts.iface_delete_config_btn", {iface=if_name}), "show_alerts.iface_delete_config_confirm",
      "if_stats.lua", {ifid=ifid},
      if_name)

elseif(page == "config") then
   if(not isAdministrator()) then
      return
   end

   print[[
   <table class="table table-bordered table-striped">]]

   if ((not interface.isPcapDumpInterface()) and
       (ifstats.name ~= nil) and
       (ifstats.name ~= "dummy")) then
      -- Custom name
      print[[
      <tr>
         <th>]] print(i18n("if_stats_config.custom_name")) print[[</th>
         <td>]]
      local label = getInterfaceNameAlias(ifstats.name)
      inline_input_form("custom_name", "Custom Name",
         i18n("if_stats_config.custom_name_popup_msg"),
         label, isAdministrator(), 'autocorrect="off" spellcheck="false" pattern="^[_\\-a-zA-Z0-9\\. ]*$"')
      print[[
         </td>
      </tr>]]

      -- Interface speed
      print[[
      <tr>
         <th>]] print(i18n("if_stats_config.interface_speed")) print[[</th>
         <td>]]
      local ifspeed = getInterfaceSpeed(ifstats)
      inline_input_form("ifSpeed", "Interface Speed",
         i18n("if_stats_config.interface_speed_popup_msg"),
         ifspeed, isAdministrator(), 'type="number" min="1"')
      print[[
         </td>
      </tr>]]

      -- Interface refresh rate
      print[[
      <tr>
         <th>]] print(i18n("if_stats_config.refresh_rate")) print[[</th>
         <td>]]
      local refreshrate = getInterfaceRefreshRate(ifstats.id)
      inline_input_form("ifRate", "Refresh Rate",
         i18n("if_stats_config.refresh_rate_popup_msg"),
         refreshrate, isAdministrator(), 'type="number" min="1"')
      print[[
         </td>
      </tr>]]
   end

   -- Scaling factor
   if interface.isPacketInterface() then
      local label = ntop.getCache(getRedisIfacePrefix(ifid)..".scaling_factor")
      if((label == nil) or (label == "")) then label = "1" end

      print[[
      <tr>
         <th>]] print(i18n("if_stats_config.scaling_factor")) print[[</th>
         <td>]]
      inline_input_form("scaling_factor", "Scaling Factor",
         i18n("if_stats_config.scaling_factor_popup_msg"),
         label, isAdministrator(), 'type="number" min="1" step="1"')
      print[[
         </td>
      </tr>]]
   end

   -- Alerts
   local trigger_alerts = true
   local trigger_alerts_checked = "checked"

   if (_POST["trigger_alerts"] ~= nil) then
      if _POST["trigger_alerts"] ~= "true" then
         trigger_alerts = false
         trigger_alerts_checked = ""
      end

      ntop.setHashCache(get_alerts_suppressed_hash_name(getInterfaceId(ifname)), ifname_clean, tostring(trigger_alerts))
   else
      trigger_alerts = ntop.getHashCache(get_alerts_suppressed_hash_name(getInterfaceId(ifname)), ifname_clean)
      if trigger_alerts == "false" then
         trigger_alerts = false
         trigger_alerts_checked = ""
      end
   end

      print [[<tr>
         <th>]] print(i18n("if_stats_config.trigger_interface_alerts")) print[[</th>
         <td>
            <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">
               <input type="hidden" name="trigger_alerts" value="]] print(not trigger_alerts) print[[">
               <input type="checkbox" value="1" ]] print(trigger_alerts_checked) print[[ onclick="this.form.submit();">
                  <i class="fa fa-exclamation-triangle fa-lg"></i>
                  ]] print(i18n("if_stats_config.trigger_alerts_for_interface", {ifname=short_name})) print[[
               </input>
               <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[["/>
            </form>
         </td>
      </tr>]]

   print[[
   </table>]]

elseif(page == "snmp_bind") then
   if ((not hasSnmpDevices(ifstats.id)) or (not is_packet_interface)) then
      return
   end

   local snmp_host = _POST["ip"]
   local snmp_interface = _POST["snmp_port_idx"] or ""

   if (snmp_host ~= nil) then
      -- snmp_host can be empty
      set_snmp_bound_interface(ifstats.id, snmp_host, snmp_interface)
   else
      local value = get_snmp_bound_interface(ifstats.id)

      if value ~= nil then
         snmp_host = value.snmp_device
         snmp_interface = value.snmp_port
      end
   end

   local snmp_devices = get_snmp_devices(ifstats.id)

   print[[
<form id="snmp_bind_form" method="post" style="margin-bottom:3em;">
   <table class="table table-bordered table-striped">]]

   print[[
      <tr>
         <th>]] print(i18n("snmp.snmp_device")) print[[</th>
         <td>
            <select class="form-control" style="width:30em; display:inline;" id="snmp_bind_device" name="ip">
               <option]] if isEmptyString(snmp_host) then print(" selected") end print[[ value="">Not Bound</option>
         ]]

   for _, device in pairs(snmp_devices) do
      print('<option value="'..device.ip..'"')
      if (snmp_host == device.ip) then
         print(' selected')
      end
      print('>'..device.name..' ('..device.ip..')</option>')
   end

   print[[
            </select>
            <a class="btn" id="snmp_device_link" style="padding:0.2em; margin-left:0.3em;" href="#"]]

   if isEmptyString(snmp_host) then
      print(" disabled")
   end

   print[[>]] print(i18n("snmp.view_device"))  print[[</i></a>
         </td>
      </tr>
      <tr>
         <th>]] print(i18n("snmp.snmp_interface")) print[[</th>
            <td>
               <select class="form-control" style="width:30em; display:inline;" id="snmp_bind_interface" name="snmp_port_idx">]]

   if not isEmptyString(snmp_interface) then
      -- This is neeeded to initialized ays form fields
      print('<option value="'..snmp_interface..'" selected></option>')
   end

   print[[
               </select>
               <img id="snmp_loading" style="margin-left:0.5em; visibility:hidden;" src="]] print(ntop.getHttpPrefix()) print[[/img/loading.gif"\>
            </td>
      </tr>
   </table>

   <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   <button id="snmp_bind_submit" class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
</form>

<b>]] print(i18n("snmp.note") .. ":") print[[</b><br>
<small>]] print(i18n("snmp.bound_interface_description")) print[[</small>

<script>
   var snmp_bind_port_ajax = null;
   var snmp_bind_first_init = true;

   function snmp_set_loading_status(is_loading) {
      if (is_loading) {
         $("#snmp_loading").css("visibility", "");
         $("#snmp_bind_submit").addClass("disabled");
      } else {
         $("#snmp_loading").css("visibility", "hidden");
         $("#snmp_bind_submit").removeClass("disabled");
      }
   }

   function snmp_check_snmp_list() {
      var iflist = $("#snmp_bind_interface");

      if ($("option", iflist).length > 0)
         iflist.removeAttr("disabled");
      else
         iflist.attr("disabled", "disabled");

      aysRecheckForm('#snmp_bind_form');
   }

   function snmp_recheck_selection() {
      var iflist = $("#snmp_bind_interface");
      var selected_device = $("#snmp_bind_device option:selected").val();

      // Remove existing entries
      $("option", iflist).remove();

      if (snmp_bind_port_ajax != null) {
         snmp_bind_port_ajax.abort();
         snmp_bind_port_ajax = null;
      }
      snmp_check_snmp_list();

      if (selected_device) {
         snmp_set_loading_status(true);
         $("#snmp_device_link").removeAttr("disabled");
         $("#snmp_device_link").attr("href", "]] print(ntop.getHttpPrefix()) print[[/lua/pro/enterprise/snmp_device_info.lua?ip=" + selected_device);

         snmp_bind_port_ajax = $.ajax({
          type: 'GET',
          url: ']]
   print (ntop.getHttpPrefix())
   print [[/lua/pro/enterprise/get_snmp_device_info.lua',
          data: { ifid: ]] print(ifstats.id) print[[, ip: selected_device, iftype_filter:'snmp_binding' },
          success: function(rsp) {
            if (rsp.interfaces) {
               for (var ifidx in rsp.interfaces) {
                  var snmp_interface = rsp.interfaces[ifidx];
                  var selected = snmp_interface.bound ? " selected" : "";
                  iflist.append('<option value="' + ifidx + '"' + selected + '>' + snmp_interface.label + '</option>');
                  snmp_interface.label;
               }

               snmp_check_snmp_list();
            }
          }, complete: function() {
            snmp_set_loading_status(false);
          }
        });
      } else {
         snmp_set_loading_status(false);
         $("#snmp_device_link").attr("disabled", "disabled");
         snmp_check_snmp_list();
      }
   }

   aysHandleForm("#snmp_bind_form");
   snmp_check_snmp_list();

   $("#snmp_bind_device").change(snmp_recheck_selection);
   $(function() {
      // let it pass some time to ays initialization
      snmp_recheck_selection();
   });
</script>]]
elseif(page == "pools") then
    if ifstats.isView then
      error()
    end

    dofile(dirs.installdir .. "/scripts/lua/admin/host_pools.lua")
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
            local qtraffic = _POST["qtraffic_"..k]
            local qtime = _POST["qtime_"..k]

            done[k] = true;
            callback(k, _POST["ishaper_"..k], _POST["eshaper_"..k], qtraffic or "0", qtime or "0")
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

   -- TODO refactor view_network logic

   local selected_pool_id = _GET["pool"] or _POST["target_pool"]
   local selected_pool = nil

   local available_pools = host_pools_utils.getPoolsList(ifId)

   for _, pool in ipairs(available_pools) do
     if pool.id == selected_pool_id then
       selected_pool = pool
     end
   end

   if selected_pool == nil then
      selected_pool = available_pools[2] or available_pools[1]
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

   if(_POST["target_pool"] ~= nil) then
      local target_pool = _POST["target_pool"]

      if (_POST["del_l7_proto"] ~= nil) then
         local protocol_id = _POST["del_l7_proto"]
         shaper_utils.deleteProtocol(ifid, target_pool, protocol_id)
      else
         -- first remove the rules which have changed protocol
         local rules_to_delete = {}
         for option,value in pairs(_POST) do
            local sp = split(option, "oldrule_")
            if #sp == 2 then
               -- mark the rule as to be deleted
               rules_to_delete[sp[2]] = true
            end
         end

         get_shapers_from_parameters(function(proto_id)
            -- A new rule will be set for the protocol, no need to delete it
            rules_to_delete[proto_id] = nil
         end)

         for proto in pairs(rules_to_delete) do
            shaper_utils.deleteProtocol(ifid, target_pool, proto)
         end

         -- set protocols policy for the pool
         get_shapers_from_parameters(function(proto_id, ingress_shaper, egress_shaper, traffic_quota, time_quota)
            shaper_utils.setProtocolShapers(ifid, target_pool, proto_id, ingress_shaper, egress_shaper, traffic_quota, time_quota)
         end)

         if (_POST["blocked_categories"] ~= nil)  then
            local sites_categories = split(_POST["blocked_categories"], ",")
            shaper_utils.setBlockedSitesCategories(ifid, target_pool, sites_categories)
         end
      end

      interface.reloadL7Rules(tonumber(selected_pool.id))
   end
   print [[
   <ul id="filterPageTabPanel" class="nav nav-tabs" role="tablist">
      <li><a data-toggle="tab" role="tab" href="#protocols">]] print(i18n("shaping.manage_policies")) print[[</a></li>
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

-- Create delete dialogs

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "delete_policy_dialog",
      action  = "deleteShapedProtocol(delete_protocol_id)",
      title   = i18n("shaping.delete_policy"),
      message = i18n("shaping.confirm_delete_policy") .. ' <span id=\"delete_policy_dialog_protocol\"></span> ' .. i18n("shaping.policy_from_pool") .. " \"" .. selected_pool.name .. "\"?",
      confirm = i18n("delete"),
    }
  })
)

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "delete_shaper_dialog",
      action  = "deleteShaper(delete_shaper_id)",
      title   = i18n("shaping.delete_shaper"),
      message = i18n("shaping.confirm_delete_shaper") .. ' <span id=\"delete_shaper_dialog_shaper\"></span>?',
      confirm = i18n("delete"),
    }
  })
)


-- ******************************************

-- ==== Manage policies tab ====

print [[<div id="protocols" class="tab-pane"><br>

<form id="deletePolicyForm" method="post">
   <input type="hidden" name="target_pool" value="]] print(selected_pool.id) print[[">
   <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   <input type="hidden" name="del_l7_proto" value="">
</form>

]] print(i18n("host_pools.pool")..":") print[[ <select id="target_pool" class="form-control pool-selector" name="pool" style="display:inline;">
]]
   for _,pool in ipairs(available_pools) do
	    print("\t<option value=\""..pool.id.."\"")
	    if(pool.id == selected_pool.id) then print(" selected") end
	    print(">"..(pool.name).."</option>\n")
   end
print('</select>')

if selected_pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
  print(' <A HREF="'..  ntop.getHttpPrefix()..'/lua/if_stats.lua?ifid='..ifid..'&page=pools&pool=') print(selected_pool.id) print('#manage" title="Edit Host Pool"><i class="fa fa-cog" aria-hidden="true"></i></A>')

  local poolstats_rrd = host_pools_utils.getRRDBase(ifstats.id, selected_pool.id)
  if ntop.getCache("ntopng.prefs.host_pools_rrd_creation") == "1" and ntop.exists(poolstats_rrd) then
    print("&nbsp; <a href='"..ntop.getHttpPrefix().."/lua/pool_details.lua?pool="..selected_pool.id.."&page=historical' title='Chart'><i class='fa fa-area-chart'></i></a>")
  end
end

print[[<form id="l7ProtosForm" onsubmit="return checkShapedProtosFormCallback();" method="post">
   <input type="hidden" name="target_pool" value="]] print(selected_pool.id) print[[">
   <input type="hidden" name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" />
]]

local protos = interface.getnDPIProtocols()
local protos_in_use = shaper_utils.getPoolProtoShapers(ifid, selected_pool.id, true --[[ do not aggregate into categories ]])
local protocol_categories = shaper_utils.getCategoriesWithProtocols()
local uses_per_member_quota = selected_pool.enforce_quotas_per_pool_member

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
   local show_groups = (not table.empty(categories)) and (not table.empty(protos))

   if show_groups then print('<optgroup label="'..i18n("shaping.protocol_families")..'">') end
   for k,category in pairsByKeys(categories, asc_insensitive) do
      print('<option value="cat_'..category.id..'"')
      if categories_disabled[category.id] ~= nil then print(' disabled="disabled"') end
      print('>' .. shaper_utils.formatCategory(k, category.count) ..'</option>'..terminator)
   end
   if show_groups then print('</optgroup>') end

   if show_groups then print('<optgroup label="'..i18n("shaping.protocols")..'">') end
   for protoName,protoId in pairsByKeys(protos, asc_insensitive) do
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
   if show_groups then print('</optgroup>') end
end

local sites_categories = ntop.getSiteCategories()
if sites_categories ~= nil then
   -- flashstart is enabled here
   local blocked_categories = shaper_utils.getBlockedSitesCategories(ifid, selected_pool.id)

   print[[<br><br>
      <table>
         <tr>
            <td valign=top style="padding-right:1em;">Content categories<br>to <b>block</b>:</td>
            <td><select id="flashstart_to_block" title="Select a category to block it" name="sites_categories" style="width:25em; height:10em;" multiple>]]
   for cat_id, cat_name in pairsByValues(sites_categories, asc) do
      print[[<option value="]] print(cat_id.."") print[["]]
      if blocked_categories[cat_id] then
         print(" selected")
      end
      print[[>]] print(firstToUpper(cat_name)) print[[</option>]]
   end
   print [[</select></td>
   </tr>
   <tr>
      <td></td>
      <td>
         <div class="text-center" style="margin-top:0.5em;">
            <input type="button" value="All" style="margin-right:1em;" onclick="$('#flashstart_to_block option').prop('selected', true); aysRecheckForm('#l7ProtosForm');">
            <input type="button" value="None" onclick="$('#flashstart_to_block option').prop('selected', false); aysRecheckForm('#l7ProtosForm');">
         </div>
      </td>
   </tr>
   </table>
   <br>]]
end

local split_shaping_directions = (ntop.getPref("ntopng.prefs.split_shaping_directions") == "1")

   print ([[<div id="table-protos"></div>
<button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]]..i18n("save_settings")..[[</button>
</form>
]])

if selected_pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
print([[<b>]]..i18n("shaping.notes")..[[</b>:]])

print([[
<ul>
<li>]]..i18n("shaping.note_drop_core")..[[</li>
<li>]]..i18n("shaping.note_quota_unlimited")..[[</li>
<li>]]..i18n("shaping.see_quotas_here", {url=ntop.getHttpPrefix().."/lua/pool_details.lua?page=quotas&pool="..selected_pool.id})..[[</li>
<li>]]..i18n("shaping.note_families")..[[
   <select id="family_info_sel" class="form-control input-sm" style="width:16em; display:inline; margin: 0 1em;">
      <option disabled selected value></option>
   ]])

   print_ndpi_families_and_protocols(protocol_categories, {}, {}, {}, "\n")
   print[[
   </select>
</li>
</ul>
<div id="family_info_protos"></div>

<script>
$("#family_info_sel").change(function() {
   var cat_id = $(this).val().split("_")[1];

   for (var cat_name in protocol_categories) {
      var cat = protocol_categories[cat_name];

      if (cat.id == cat_id) {
         var proto_list = [];

         for (var proto in cat.protos)
            proto_list.push(proto);

         proto_list.sort();
         $("#family_info_protos").html("<b>" + cat_name + " ]] print(i18n("shaping.protocols")) print[[</b>: " + proto_list.join(", "));
      }
   }
});
</script>
]]
end

local rate_buttons = shaper_utils.buttons("rate")
local traffic_buttons = shaper_utils.buttons("traffic")
local time_buttons = shaper_utils.buttons("time")

print("<script>")
print(rate_buttons.init.."\n")

local empty_quota_bar = string.gsub(string.gsub(printProtocolQuota({traffic_quota="0"}, {}, nil, {traffic=true}, false, true), "\n", ""), "'", "\"")

print[[
var rate_buttons_code = ']] print(rate_buttons.js) print[[';
var rate_buttons_html = '<table style="width:100%"><tr><td>]] print(rate_buttons.html) print[[</td></tr></table>';

var traffic_buttons_code = ']] print(traffic_buttons.js) print[[';
var traffic_buttons_html = '<table style="width:100%"><tr><td>]] print(traffic_buttons.html)
print[[</td><td style="width:35%" class="]] if uses_per_member_quota then print("hidden") end print[[">]]
print(empty_quota_bar)
print[[</tr></table>';

var time_buttons_code = ']] print(time_buttons.js) print[[';
var time_buttons_html = '<table style="width:100%"><tr><td>]] print(time_buttons.html)
print[[</td><td style="width:35%" class="]] if uses_per_member_quota then print("hidden") end print[[">]]
print(empty_quota_bar)
print[[</tr></table>';

/* Note: do not change */
var rowid_prefix = "proto_policy_row_";
var oldid_prefix = rowid_prefix + "old_";
var newid_prefix = rowid_prefix + "new_";

function replaceCtrlId(v, with_this) {
   return v.replace(/\_\_\_CTRL\_ID\_\_\_/g, with_this);
}

function makeResolutionButtonsAtRuntime(td_object, template_html, template_js, input_name, extra) {
   var extra = extra || {};
   var value = (extra.value !== undefined) ? (extra.value) : (td_object.html());
   var disabled = extra.disabled;
   var hidden = extra.hidden;
   var maxvalue = extra.max_value;
   var minvalue = extra.min_value;

   // fix ctrl id
   var buttons = $(replaceCtrlId(template_html, input_name));
   var div = $('<div class="text-center form-group" style="padding:0; margin:0;"></div>');
   td_object.html("");
   div.appendTo(td_object);
   buttons.appendTo(div);

   var input = $('<input name="' + input_name + '" class="form-control" type="number" style="width:6em; text-align:right; margin-left:0.5em; display:inline;" required/>');
   if (maxvalue !== null)
      input.attr("data-max", maxvalue);

   input.attr("data-min", (minvalue !== null) ? minvalue : -1);
   input.appendTo($("td:first", div));

   if (disabled) {
      input.attr("disabled", "disabled");
      buttons.find("label").attr("disabled", "disabled");
   }

   // Add steps if available
   for (resol in extra.steps)
      input.attr("data-step-"+resol, extra.steps[resol]);

   // execute group specific code
   eval(replaceCtrlId(template_js, input_name));

   // set initial value
   resol_selector_set_value(input, value);

   return input;
}

function makeShapersDropdownCallback(suffix, ingress_shaper_idx, egress_shaper_idx) {
   var ingress_shaper = $("td:nth-child("+ingress_shaper_idx+")", $(this));
   var egress_shaper = $("td:nth-child("+egress_shaper_idx+")", $(this));
   var ingress_shaper_id = ingress_shaper.html();
   var egress_shaper_id = egress_shaper.html();
]]

print[[

   ingress_shaper.html('<select class="form-control shaper-selector" name="ishaper_'+suffix+'">]] print_shapers(shapers, "", "\\\n") print[[</select>');
   egress_shaper.html('<select class="form-control shaper-selector" name="eshaper_'+suffix+'">]] print_shapers(shapers, "", "\\\n") print[[</select>');

   /* Select the current value */
   $("select", ingress_shaper).val(ingress_shaper_id);
   $("select", egress_shaper).val(egress_shaper_id);
}

/* -------------------------------------------------------------------------- */

   $("#target_pool").change(function() {
      document.location.href = "]] print(ntop.getHttpPrefix()) print [[/lua/if_stats.lua?page=filtering&pool="+$("#target_pool").val()+"#protocols";
   });

   function checkShapedProtosFormCallback() {
      /* Handle existing protocols change */
      var old_protos = $("tr[id^='"+oldid_prefix+"']");

      old_protos.each(function() {
         var old_rule = $(this);
         var proto_sel = $("td:nth-child(1) > select", old_rule);
         var old_proto = proto_sel.attr("name");
         var new_proto = $("option:selected", proto_sel).val();

         if (old_proto !== new_proto) {
            /* The protocol selection has changed, mark the old protocol */
            $('<input name="oldrule_'+old_proto+'" type="hidden"/>')
               .appendTo($("#l7ProtosForm"));

            /* Also change the assocociated rule names */
            $("[name]", $("td", old_rule).slice(1)).each(function() {
               $(this).attr("name", $(this).attr("name").replace(old_proto, new_proto));
            });
         }

         /* Remove the name attribute, it is not needed anymore */
         proto_sel.removeAttr("name");
      });

      /* Handle new protos */
      var new_protos = $("tr[id^='"+newid_prefix+"']");

      new_protos.each(function() {
         var new_proto = $(this);
         var td_proto = $("td:nth-child(1)", new_proto);
         var td_ingress_shaper = $("td:nth-child(2)", new_proto);
         var td_egress_shaper = $("td:nth-child(3)", new_proto);
         var td_traffic_quota = $("td:nth-child(4)", new_proto);
         var td_time_quota = $("td:nth-child(5)", new_proto);

         var selected = $("option:selected", td_proto);
         var proto_id = selected.val();

         /* set form fields names to match datatable generated ones */
         $("select", td_proto).attr('name', '');
         $("select", td_ingress_shaper).attr('name', 'ishaper_'+proto_id);
         $("select", td_egress_shaper).attr('name', 'eshaper_'+proto_id);
         $("input:last", td_traffic_quota).attr('name', 'qtraffic_'+proto_id);
         $("input:last", td_time_quota).attr('name', 'qtime_'+proto_id);
      });

      ]]
if not split_shaping_directions then
   print[[
      /* Since shaping directions are linked, we have to set both shapers to the same value */
      var tprotos = $("#table-protos");
      $("select[name^='ishaper_']", tprotos).each(function() {
         var proto_id = $(this).attr("name").split("ishaper_")[1];
         var egress = $("select[name='eshaper_" + proto_id + "']", tprotos);
         egress.val($(this).val());
      });
   ]]
end
print[[

      /* Possibly handle multiple blocked categories */
      var sites_categories = $("#l7ProtosForm select[name='sites_categories']");
      if (sites_categories.length == 1) {
         var selection = [];
         $("option:selected", sites_categories).each(function() {
            selection.push($(this).val());
         });

         /* Create the joint field */
         sites_categories.attr('name', '');
         $('<input name="blocked_categories" type="hidden"/>')
            .val(selection.join(","))
            .appendTo($("#l7ProtosForm"));
      }

      return true;
   }

   var new_row_ctr = 0;
   var protocol_categories = ]] print(json.encode(protocol_categories)) print[[;
   var quota_update = null;
   var quota_update_xhr = null;

   function quotaUpdateCallback() {
      if (quota_update_xhr !== null) {
         quota_update_xhr.abort();
         quota_update_xhr = null;
      }

      quota_update_xhr = $.ajax({
         type: "GET",
         url: "]] print(ntop.getHttpPrefix()) print[[/lua/pro/pool_details_ndpi.lua",
         data: {pool: ]] print(selected_pool.id) print[[, include_unlimited:true},
         success: function(response) {
            var rsp = $("<table>"+response+"</table>");

            $("#table-protos table:first tr").each(function() {
               var proto_id = $("td:first select", $(this)).val();

               if (typeof(proto_id) !== "undefined") {
                  var tr_quota = $("tr[data-protocol='" + proto_id + "']", rsp);
                  var traffic_quota = $("td:nth-child(4) div.progress", $(this)).parent();
                  var time_quota = $("td:nth-child(5) div.progress", $(this)).parent();

                  if (tr_quota.length === 1) {
                     var input_traffic_bar = $("div.progress:first", tr_quota);
                     var traffic_label = input_traffic_bar.closest("td").find("> span");
                     traffic_quota.html("<small>" + traffic_label.html() + "</small>");
                     input_traffic_bar
                        .css("height", "20px")
                        .css("margin", "2px 0 12px 0")
                        .appendTo(traffic_quota);

                     var input_time_bar = $("div.progress:last", tr_quota);
                     var time_label = input_time_bar.closest("td").find("> span");
                     time_quota.html("<small>" + time_label.html() + "</small>");
                     input_time_bar
                        .css("height", "20px")
                        .css("margin", "2px 0 12px 0")
                        .appendTo(time_quota);
                  } else {
                     traffic_quota.html(']] print(empty_quota_bar) print[[');
                     time_quota.html(']] print(empty_quota_bar) print[[');
                  }
               }
            });
         }
      });

      /* Periodic timeout */
      quota_update = setTimeout(quotaUpdateCallback, 5000);
   }

   function refreshQuotas() {]]

   if not ntop.isEnterprise() then
      -- no need to update quotas as they are not supported
      print("return;")
   end

   print[[
      if (quota_update !== null) {
         clearTimeout(quota_update);
         quota_update = null;
      }

      /* Reduced timeout (only once) */
      quota_update = setTimeout(quotaUpdateCallback, 10);
   }

   function addNewShapedProto() {
      var newid = newid_prefix + new_row_ctr;
      new_row_ctr += 1;

      var tr = $('<tr id="' + newid + '" ><td class="text-center text-middle"></td><td class="text-center text-middle"><select class="form-control shaper-selector" name="ingress_shaper_id">\
]] print_shapers(shapers, "0", "\\") print[[
      </select></td><td class="text-center text-middle" ]] if not split_shaping_directions then print(" hidden") end
   print[[><select class="form-control shaper-selector" name="egress_shaper_id">\
]] print_shapers(shapers, "0", "\\") print[[
         </optgroup>\
      </select></td>\]]

      if ntop.isEnterprise() then
      	 print[[<td class="text-center text-middle">-1</td><td class="text-center text-middle">-1</td>\]]
      end

      print[[<td class="text-center text-middle"></td></tr>');
      $("#table-protos table:first").append(tr);

      makeProtocolNameDropdown(tr);]]

      if ntop.isEnterprise() then
      	 print[[
      	 makeTrafficQuotaButtons(tr, newid);
      	 makeTimeQuotaButtons(tr, newid);
	 ]]
      end


      print [[datatableAddDeleteButtonCallback.bind(tr)(6, "datatableUndoAddRow('#" + newid + "', ']] print(i18n("shaping.no_shapers_available")) print[[')", "]] print(i18n('undo')) print[[");
      aysRecheckForm('#l7ProtosForm');
   }

   function deleteShapedProtocol(proto_id) {
      var form = $("#deletePolicyForm");
      var todel = $("input[name='del_l7_proto']", form);

      todel.val(proto_id);
      form.submit();
   }

   function makeProtocolNameDropdown(tr_obj, selected_proto) {
      var name = selected_proto || "new_protocol_id";

      var input = $('<select class="form-control"></select>')
         .attr("name", name)
         .html(']] print_ndpi_families_and_protocols(protocol_categories, protos, {}, {}, "\\") print[[')
         .change(refreshQuotas);

      $("td:first", tr_obj).html(input);

      datatableMakeSelectUnique(tr_obj, rowid_prefix, {
         on_change: function(select, old_val, new_val, others, change_fn) {

            function changeConditionally(option, to_enable) {
               /* NOTE: Remove this return to enable protocol-category mutual exclusion */
               //return;

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

      if (name !== "new_protocol_id")
         $("option[value='"+name+"']", input).prop('selected', true);
   }

   function makeTrafficQuotaButtons(tr_obj, proto_id) {
      if (proto_id === "default")
         $("td:nth-child(4)", tr_obj).html("");
      else
         makeResolutionButtonsAtRuntime($("td:nth-child(4)", tr_obj), traffic_buttons_html, traffic_buttons_code, "qtraffic_" + proto_id, {
            max_value: 100*1024*1024*1024 /* 100 GB */,
            min_value: 0,
         });
   }

   function makeTimeQuotaButtons(tr_obj, proto_id) {
      if (proto_id === "default")
         $("td:nth-child(5)", tr_obj).html("");
      else
         makeResolutionButtonsAtRuntime($("td:nth-child(5)", tr_obj), time_buttons_html, time_buttons_code, "qtime_" + proto_id, {
            max_value: 23*60*60 /* 23 hours */,
            min_value: 0,
         });
   }

   $("#table-protos").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_l7_proto_policies.lua?ifid=]] print(ifid.."") print[[&pool=]] print(selected_pool.id) print[[",
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
              width: '12%',
               verticalAlign: 'middle'
            }
         }, {]]
   if split_shaping_directions then
      print[[
            title: "]] print(i18n("shaping.traffic_to") .. " " .. selected_pool.name) print[[",
      ]]
   else
      print[[
            title: "]] print(i18n("shaping.protocol_policy")) print[[",
      ]]
   end
   print[[
            field: "column_ingress_shaper",
            css: {
               width: '12%',
               textAlign: 'center',
               verticalAlign: 'middle'
            }
         }, {]]

   -- If directions are linked, hide the *egress* shaper
   if not split_shaping_directions then
      print[[
            hidden: true,
      ]]
   end

   -- quotas are only supported in the enterprise edition
   local quota_hidden = false
   if not ntop.isEnterprise() then
      quota_hidden = true
   end

   print[[
            title: "]] print(i18n("shaping.traffic_from") .. " " .. selected_pool.name) print[[",
            field: "column_egress_shaper",
            css: {
               width: '10%',
               textAlign: 'center',
               verticalAlign: 'middle'
            }
         }, {
            title: "]] print(i18n("shaping.daily_traffic_quota")) print[[",
            field: "column_traffic_quota",
	    hidden: ]] print(quota_hidden) print[[,
            css : {
               width: '20%',
               textAlign: 'center',
               verticalAlign: 'middle'
            }
         }, {
            title: "]] print(i18n("shaping.daily_time_quota")) print[[",
            field: "column_time_quota",
	    hidden: ]] print(quota_hidden) print[[,
            css : {
               width: '20%',
               textAlign: 'center',
               verticalAlign: 'middle',
            }
         }, {
            title: "]] print(i18n("actions")) print[[",
            css : {
               width: '8%',
               textAlign: 'center',
               verticalAlign: 'middle'
            }
         }
      ], tableCallback: function() {
]]

if selected_pool.id == host_pools_utils.DEFAULT_POOL_ID then
   print[[
         datatableForEachRow("#table-protos", function() {
            $(this).remove();
         });

         datatableAddEmptyRow("#table-protos", "]] print(i18n("shaping.note_default_pool_config", {url=ntop.getHttpPrefix().."/lua/if_stats.lua?page=pools#create"})) print[[");
         $("#addNewShapedProtoBtn").attr("disabled", "true");
   ]]
else
   print[[
         var proto_id;

         datatableForEachRow("#table-protos", [
            function() {
               proto_id = $("td:nth-child(1) span", $(this)).attr("data-proto-id");
            }, function() {
               makeShapersDropdownCallback.bind(this)(proto_id, 2, 3);
            }, function() {
               if (proto_id !== "default") {
                  $(this).attr("id", oldid_prefix + proto_id);
                  makeProtocolNameDropdown($(this), proto_id);
               }
               makeTrafficQuotaButtons($(this), proto_id);
               makeTimeQuotaButtons($(this), proto_id);

               var value = $("td:nth-child(1) span", $(this)).html();
               if (proto_id != ']] print(shaper_utils.POOL_SHAPER_DEFAULT_PROTO_KEY) print[[')
                  datatableAddDeleteButtonCallback.bind(this)(6, "delete_protocol_id ='" + proto_id + "'; $('#delete_policy_dialog_protocol').html('" + value +"'); $('#delete_policy_dialog').modal('show');", "]] print(i18n('delete')) print[[");
            }
         ]);

         $("#addNewShapedProtoBtn").attr("disabled", ! datatableIsLastPage("#table-protos"));
         aysResetForm('#l7ProtosForm');
   ]]
end

print[[
      }
   });
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

   function shaperRateTextField(td_object, shaper_id, value) {
      var input_name = "shaper_" + shaper_id;
      var disabled = false;

      if ((shaper_id == ]] print(shaper_utils.DEFAULT_SHAPER_ID) print[[) ||
          (shaper_id == ]] print(shaper_utils.BLOCK_SHAPER_ID) print[[))
         disabled = true;

      var input = makeResolutionButtonsAtRuntime(td_object, rate_buttons_html, rate_buttons_code, input_name, {
         value: value,
         disabled: disabled,
         max_value: ]] print(tostring(SHAPERS_MAX_RATE_KPBS)) print[[
      });

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
         datatableAddDeleteButtonCallback.bind(tr_obj)(4, "delete_shaper_id ='" + shaper_id + "'; $('#delete_shaper_dialog_shaper').html('" + shaper_id +"'); $('#delete_shaper_dialog').modal('show');", "]] print(i18n('delete')) print[[");

         var applied_to = $("td:nth-child(3)", tr_obj);
         if (applied_to.html() != "&nbsp;")
            // this shaper is in use
            $("td:nth-child(4) a", tr_obj).attr("disabled", "disabled");
      }
   }

   $("#table-shapers").datatable({
      url: "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_shapers.lua?ifid=]] print(ifid.."") print[[",
      title: "",
      hidePerPage: true,
      perPage: ]] print(tostring(shaper_utils.MAX_NUM_SHAPERS)) print[[,
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
            shaperRateTextField(max_rate, shaper_id, max_rate.html());

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
   handle_tab_state($("#filterPageTabPanel"), "protocols");

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
    data: 'resetstats_mode=' + action + "&csrf=]] print(ntop.getRandomCSRFValue()) print[[",
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
	  data: { iffilter: "]] print(tostring(interface.name2id(ifstats.name))) print [[" },
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
	var last_pkt_retransmissions = ]] print(tostring(ifstats.tcpPacketStats.retransmissions)) print [[;
	var last_pkt_ooo =  ]] print(tostring(ifstats.tcpPacketStats.out_of_order)) print [[;
	var last_pkt_lost = ]] print(tostring(ifstats.tcpPacketStats.lost)) print [[;

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
            /* If rsp.flow_export_count means that only drops have been occurring so it is meaningless to print a pct */
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
	if(rsp.drops + rsp.flow_export_drops != 0) {
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
       }, ]] print(getInterfaceRefreshRate(ifstats.id).."") print[[ * 1000)

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
