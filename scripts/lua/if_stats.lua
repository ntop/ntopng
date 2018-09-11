--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
   require "snmp_utils"
end

local json = require "dkjson"
local host_pools_utils = require "host_pools_utils"
local template = require "template_utils"
local os_utils = require "os_utils"

require "lua_utils"
require "prefs_utils"
require "graph_utils"
require "alert_utils"
require "db_utils"
local ts_utils = require "ts_utils"

local have_nedge = ntop.isnEdge()

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
   if(can_edit) then
      print('<input style="width:12em;" title="'..tooltip..'" '..(input_opts or "")..' class="form-control '..(input_class or "")..'" name="'..name..'" placeholder="'..placeholder..'" value="')
      if(value ~= nil) then print(value.."") end
      print[[">]]
   else
      if(value ~= nil) then print(value) end
   end
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
local is_packetdump_enabled = isLocalPacketdumpEnabled()
local is_packet_interface = interface.isPacketInterface()

local ifstats = interface.getStats()

-- this is a user-browseable page, so we must return counters from
-- the latest reset as the user may have chosen to reset statistics at some point
if ifstats.stats and ifstats.stats_since_reset then
   -- override stats with the values calculated from the latest user reset
   for k, v in pairs(ifstats.stats_since_reset) do
      ifstats.stats[k] = v
   end
end

if (isAdministrator()) then
   if (page == "config") and (not table.empty(_POST)) then
      -- TODO move keys to new schema: replace ifstats.name with ifid
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.name',_POST["custom_name"])

      local ifspeed_cache = 'ntopng.prefs.'..ifstats.name..'.speed'
      if isEmptyString(_POST["ifSpeed"]) then
         ntop.delCache(ifspeed_cache)
      else
         ntop.setCache(ifspeed_cache, _POST["ifSpeed"])
      end

      local hide_set = getHideFromTopSet(ifstats.id)
      ntop.delCache(hide_set)

      for _, net in pairs(split(_POST["hide_from_top"] or "", ",")) do
         net = trimSpace(net)

         if not isEmptyString(net) then
            local address, prefix = splitNetworkPrefix(net)

            if isIPv6(address) and prefix == "128" then
               net = address
            elseif isIPv4(address) and prefix == "32" then
               net = address
            end

            ntop.setMembersCache(hide_set, net)
         end
      end

      interface.reloadHideFromTop()

      setInterfaceRegreshRate(ifstats.id, tonumber(_POST["ifRate"]))

      local sf = tonumber(_POST["scaling_factor"])
      if(sf == nil) then sf = 1 end
      ntop.setCache(getRedisIfacePrefix(ifid)..'.scaling_factor',tostring(sf))
      interface.loadScalingFactorPrefs()
   end

   if is_packetdump_enabled and (page == "packetdump") and (_SERVER["REQUEST_METHOD"] == "POST") then
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_all_traffic', ternary(isEmptyString(_POST["dump_all_traffic"]), "false", "true"))
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_tap', ternary(isEmptyString(_POST["dump_traffic_to_tap"]), "false", "true"))
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_disk', ternary(isEmptyString(_POST["dump_traffic_to_disk"]), "false", "true"))
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_unknown_traffic', ternary(isEmptyString(_POST["dump_unknown_to_disk"]), "false", "true"))
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_sampling_rate', _POST["sampling_rate"])
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_pkts_file', _POST["max_pkts_file"])
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_sec_file',_POST["max_sec_file"])
      local max_files = ternary(not isEmptyString(_POST["max_files"]), _POST["max_files"], 500)
      max_files = tonumber(max_files) * 1e6
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_files', tostring(max_files))

      interface.loadDumpPrefs()
   end
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

print("<link href=\""..ntop.getHttpPrefix().."/css/tablesorted.css\" rel=\"stylesheet\">")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print(msg)

url = ntop.getHttpPrefix()..'/lua/if_stats.lua?ifid=' .. ifid

--  Added global javascript variable, in order to disable the refresh of pie chart in case
--  of historical interface
print('\n<script>var refresh = '..getInterfaceRefreshRate(ifstats.id)..' * 1000; /* ms */;</script>\n')

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]

local short_name = getHumanReadableInterfaceName(ifname)

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
elseif not have_nedge then
  print("<li><a href=\""..url.."&page=ICMP\">" .. i18n("icmp") .. "</a></li>")
end

-- only show if the interface has seen mac addresses
if ifstats["has_macs"] then
   if(page == "ARP") then
     print("<li class=\"active\"><a href=\"#\">" .. i18n("arp") .. "</a></li>\n")
   elseif not have_nedge then
     print("<li><a href=\""..url.."&page=ARP\">" .. i18n("arp") .. "</a></li>")
   end
end

if(ts_utils.exists("iface:traffic", {ifid=ifid}) and not is_historical) then
   if(page == "historical") then
      print("<li class=\"active\"><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   else
      print("<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   end
end


if not have_nedge and (table.len(ifstats.profiles) > 0) then
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

if(isAdministrator() and areAlertsEnabled() and not ifstats.isView) then
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

if ts_utils.getDriverName() == "rrd" then
if(ntop.isEnterprise()) then
      if(page == "traffic_report") then
         print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-file-text report-icon'></i></a></li>\n")
      else
         print("\n<li><a href=\""..url.."&page=traffic_report\"><i class='fa fa-file-text report-icon'></i></a></li>")
      end
elseif not have_nedge then
      print("\n<li><a href=\"#\" title=\""..i18n('enterpriseOnly').."\"><i class='fa fa-file-text report-icon'></i></A></li>\n")
end
end

if(isAdministrator()) then
   if(page == "config") then
      print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-cog fa-lg\"></i></a></li>\n")
   elseif interface.isPcapDumpInterface() == false then
      print("\n<li><a href=\""..url.."&page=config\"><i class=\"fa fa-cog fa-lg\"></i></a></li>")
   end
end

if isAdministrator() and (not ifstats.isView) then
   local num_pool_hosts = ifstats.num_members.num_hosts
   local label

   if(ifstats.num_members_per_pool[host_pools_utils.DEFAULT_POOL_ID]) then
      -- don't show unassigned hosts in the counter
      num_pool_hosts = num_pool_hosts - ifstats.num_members_per_pool[host_pools_utils.DEFAULT_POOL_ID].num_hosts
   end

   if(num_pool_hosts > 0) then
      label = "<span class='badge badge-top-right'>".. num_pool_hosts .."</span>"
   else
      label = ""
   end

   if not have_nedge then
      if(page == "pools") then
         print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-users\"></i> "..label.."</a></li>\n")
      else
         print("\n<li><a href=\""..url.."&page=pools\"><i class=\"fa fa-users\"></i> "..label.."</a></li>")
      end
   end
end

if(hasSnmpDevices(ifstats.id) and is_packet_interface and false --[[disabled: no functionality provided right now]]) then
   if(page == "snmp_bind") then
      print("\n<li class=\"active\"><a href=\"#\">" .. i18n("if_stats_overview.snmp") .. "</li>")
   else
      print("\n<li><a href=\""..url.."&page=snmp_bind\">" .. i18n("if_stats_overview.snmp") .. "</a></li>")
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

   if interface.isPcapDumpInterface() == false and ifstats["type"] ~= "netfilter" then
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
      local num_remote_flow_exports, num_remote_flow_exporters = '', ''

      if not isEmptyString(ifstats["remote.if_addr"]) then
	 remote_if_addr = "<b>"..i18n("if_stats_overview.interface_ip").."</b>: "..ifstats["remote.if_addr"]
      end

      if not isEmptyString(ifstats["probe.ip"]) then
	 remote_probe_ip = "<b>"..i18n("if_stats_overview.probe_ip").."</b>: "..ifstats["probe.ip"]
      end

      if not isEmptyString(ifstats["probe.public_ip"]) then
         remote_probe_public_ip = "<b>"..i18n("if_stats_overview.public_probe_ip").."</b>: <A HREF=\"http://"..ifstats["probe.public_ip"].."\">"..ifstats["probe.public_ip"].."</A> <i class='fa fa-external-link'></i></td>\n"
      end

      if not isEmptyString(ifstats["zmq.num_flow_exports"]) then
	 num_remote_flow_exports = "<b>"..i18n("if_stats_overview.probe_zmq_num_flow_exports").."</b>: <span id=if_num_remote_zmq_flow_exports>"..formatValue(ifstats["zmq.num_flow_exports"]).."</span>"
      end

      if not isEmptyString(ifstats["zmq.num_exporters"]) then
	 num_remote_flow_exporters = "<b>"..i18n("if_stats_overview.probe_zmq_num_endpoints").."</b>: <span id=if_num_remote_zmq_exporters>"..formatValue(ifstats["zmq.num_exporters"]).."</span>"
      end

      print("<tr><th rowspan=2>"..i18n("if_stats_overview.remote_probe").."</th><td nowrap><b>"..i18n("if_stats_overview.interface_name").."</b>: "..ifstats["remote.name"].." [ ".. maxRateToString(ifstats.speed*1000) .." ]</td>")
      print("<td nowrap>"..remote_if_addr.."</td>")
      print("<td nowrap>"..remote_probe_ip.."</td>")
      print("<td nowrap colspan=2>"..remote_probe_public_ip.."</td>\n")
      print("</tr>\n")

      print("<tr>")
      print("<td nowrap><b>"..i18n("if_stats_overview.probe_timeout_lifetime").."</b>: "..secondsToTime(ifstats["timeout.lifetime"]).."</td>")
      print("<td nowrap><b>"..i18n("if_stats_overview.probe_timeout_idle").."</b>: "..secondsToTime(ifstats["timeout.idle"]).."</td>")
      print("<td nowrap colspan=3>"..num_remote_flow_exporters.."</td>")
      print("</tr>")
   end

   local is_physical_iface = (interface.isPacketInterface()) and (interface.isPcapDumpInterface() == false)
   local is_bridge_iface = (ifstats["bridge.device_a"] ~= nil) and (ifstats["bridge.device_b"] ~= nil)

   if not is_bridge_iface then
      local label = getHumanReadableInterfaceName(ifstats.name)
      local s
      if ((not isEmptyString(label)) and (label ~= ifstats.name)) then
         s = label.." (" .. ifstats.name .. ")"
      else
         s = ifstats.name
      end

      if((isAdministrator()) and (interface.isPcapDumpInterface() == false)) then
	 s = s .. " <a href=\""..url.."&page=config\"><i class=\"fa fa-cog fa-sm\" title=\"Configure Interface Name\"></i></a>"
      end
      
      print('<tr><th width="250">'..i18n("name")..'</th><td colspan="2">' .. s ..' </td>\n')
   else
      print("<tr><th>"..i18n("bridge").."</th><td colspan=2>"..ifstats["bridge.device_a"].." <i class=\"fa fa-arrows-h\"></i> "..ifstats["bridge.device_b"])

      if(user_group == "administrator") and isBridgeInterface(ifstats) and ntop.isEnterprise() and not have_nedge then
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

   if(ifstats.has_traffic_directions) then
      print(" ".. i18n("if_stats_overview.has_traffic_directions") .. " ")
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
   print("<tr><th nowrap>"..i18n("if_stats_overview.collected_flows").."</th><td width=20%><span id=if_zmq_flows>"..formatValue(ifstats.zmqRecvStats.flows).."</span></td>")
   print("<th nowrap>"..i18n("if_stats_overview.interface_rx_updates").."</th><td width=20%><span id=if_zmq_events>"..formatValue(ifstats.zmqRecvStats.events).."</span></td>")
   print("<th nowrap>"..i18n("if_stats_overview.sflow_counter_updates").."</th><td width=20%><span id=if_zmq_counters>"..formatValue(ifstats.zmqRecvStats.counters).."</span></td></tr>")
   print("<tr><th nowrap>"..i18n("if_stats_overview.zmq_message_drops").."</th><td width=20%><span id=if_zmq_msg_drops>"..formatValue(ifstats.zmqRecvStats.zmq_msg_drops).."</span></td></tr>")
   end

   print("<tr><th colspan=7 nowrap>"..i18n("if_stats_overview.ingress_traffic").."</th></tr>\n")
   print("<tr><th nowrap>"..i18n("if_stats_overview.received_traffic").."</th><td width=20%><span id=if_bytes>"..bytesToSize(ifstats.stats.bytes).."</span> [<span id=if_pkts>".. formatValue(ifstats.stats.packets) .. " ".. label .."</span>] ")
   print("<span id=pkts_trend></span></td>")

   if ifstats.isDynamic == false then
      print("<th width=20%><span id='if_packet_drops_drop'><i class='fa fa-tint' aria-hidden='true'></i></span> ")

      print(i18n("if_stats_overview.dropped_packets").."</th>")

      print("<td width=20% colspan=3><span id=if_drops>")

      if(ifstats.stats.drops > 0) then
	 print('<span class="label label-danger">')
      end

      print(formatValue(ifstats.stats.drops).. " " .. label)

      if((ifstats.stats.packets+ifstats.stats.drops) > 0) then
	 local pctg = round((ifstats.stats.drops*100)/(ifstats.stats.packets+ifstats.stats.drops), 2)
	 if(pctg > 0) then print(" [ " .. pctg .. " % ] ") end
      end

      if(ifstats.stats.drops > 0) then print('</span>') end
      print("</span>&nbsp;<span id=drops_trend></span>")

      if(ifstats.zmqRecvStats ~= nil) then
	 print("<p><small> <b>"..i18n("if_stats_overview.note").."</b>:<br>".. i18n("if_stats_overview.note_drops_sflow").."</small>")
      end
      
      print("</td>")
   else
      print("<td width=20% colspan=3>")
      print("<small><b>"..i18n("if_stats_overview.note")..":</b> "..i18n("if_stats_overview.note_drop_ifstats_dynamic").."</small>")
      print("</td>")
   end      

   print("</tr>")

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
      elseif export_drops > 0 then
         export_drops_pct = 100
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
   
   if (isAdministrator() and ifstats.isView == false and ifstats.isDynamic == false) then
      print("<tr><th>"..i18n("download").."&nbsp;<i class=\"fa fa-download fa-lg\"></i></th><td colspan=4>")

      local live_traffic_utils = require("live_traffic_utils")
      live_traffic_utils.printLiveTrafficForm(ifId)

      print("</td></tr>\n")
      
      print("<tr><th width=250>"..i18n("if_stats_overview.reset_counters").."</th>")
      print("<td colspan=5>")

      local tot	= ifstats.stats.bytes + ifstats.stats.packets + ifstats.stats.drops
      if(ifstats.stats.flow_export_count ~= nil) then
      	tot = tot + ifstats.stats.flow_export_count + ifstats.stats.flow_export_drops
      end
      
      print('<button id="btn_reset_all" type="button" class="btn btn-default" onclick="resetInterfaceCounters(false);">'..i18n("if_stats_overview.all_counters")..'</button>&nbsp;')

      print('<button id="btn_reset_drops" type="button" class="btn btn-default" onclick="resetInterfaceCounters(true);">'..i18n("if_stats_overview.drops_only")..'</button>')
      print("</td>")

      print("</tr>\n")
   end

   if have_nedge and ifstats.type == "netfilter" and ifstats.netfilter then
      local st = ifstats.netfilter

      print("<tr><th nowrap>"..i18n("if_stats_overview.nf_queue_total").."</th>")
      local span_class = ''
      if st.nfq.queue_pct > 80 then
	 span_class = "class='label label-danger'"
      end
      print("<td width=20%><span id=nfq_queue_total "..span_class..">"..string.format("%s [%s %%]", formatValue(st.nfq.queue_total), formatValue(st.nfq.queue_pct)).." </span> <span id=nfq_queue_total_trend></span></td>")
      print("<th nowrap>"..i18n("if_stats_overview.nf_handle_packet_failed").."</th>")
      print("<td width=20%><span id=nfq_handling_failed>"..formatValue(st.failures.handle_packet).."</span> <span id=nfq_handling_failed_trend></span></td>")
      print("<th nowrap>"..i18n("if_stats_overview.nf_enobufs").."</th>")
      print("<td width=20%><span id=nfq_enobufs>"..formatValue(st.failures.no_buffers).."</span> <span id=nfq_enobufs_trend></span></td>")
      print("</tr>")

      print("<tr><th nowrap>Conntrack Flow Entries</th><td colspan=5>")
      print("<span id=num_conntrack_entries>"..formatValue(st.nfq.num_conntrack_entries).."</span></td>")
      print("</tr>")
  end

   print [[
   <tr><td colspan=7> <small> <b>]] print(i18n("if_stats_overview.note").."</b>:<p>"..i18n("if_stats_overview.note_packets")) print[[</small> </td></tr>
   ]]

   print("</table>\n")

   if show_bridge_wizard then
      dofile(dirs.installdir .. "/scripts/lua/inc/bridge_wizard.lua")
   end
elseif((page == "packets")) then
   local nedge_hidden = ternary(have_nedge, 'class="hidden"', '')

   print [[ <table class="table table-bordered table-striped"> ]]
   print("<tr " .. nedge_hidden .. "><th width=30% rowspan=3>" .. i18n("packets_page.tcp_packets_analysis") .. "</th><th>" .. i18n("packets_page.retransmissions") .."</th><td align=right><span id=pkt_retransmissions>".. formatPackets(ifstats.tcpPacketStats.retransmissions) .."</span> <span id=pkt_retransmissions_trend></span></td></tr>\n")
   print("<tr " .. nedge_hidden .. "></th><th>" .. i18n("packets_page.out_of_order") .. "</th><td align=right><span id=pkt_ooo>".. formatPackets(ifstats.tcpPacketStats.out_of_order) .."</span> <span id=pkt_ooo_trend></span></td></tr>\n")
   print("<tr " .. nedge_hidden .. "></th><th>" .. i18n("packets_page.lost") .. "</th><td align=right><span id=pkt_lost>".. formatPackets(ifstats.tcpPacketStats.lost) .."</span> <span id=pkt_lost_trend></span></td></tr>\n")

    if(ifstats.type ~= "zmq") then
      print [[<tr ]] print(nedge_hidden) print[[><th class="text-left">]] print(i18n("packets_page.size_distribution")) print [[</th><td colspan=5><div class="pie-chart" id="sizeDistro"></div></td></tr>]]
    end

    print[[
  	 <tr ]] print(nedge_hidden) print[[><th class="text-left">]] print(i18n("packets_page.tcp_flags_distribution")) print[[</th><td colspan=5><div class="pie-chart" id="flagsDistro"></div></td></tr>
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
    <tr>
      <th class="text-left">]] print(i18n("ndpi_page.overview", {what = i18n("ndpi_page.application_protocol")})) print [[</th>
      <td colspan=3><div class="pie-chart" id="topApplicationProtocols"></div></td>
      <td colspan=2><div class="pie-chart" id="topApplicationBreeds"></div></td>
    </tr>
    <tr>
      <th class="text-left">]] print(i18n("ndpi_page.overview", {what = i18n("ndpi_page.application_protocol_category")})) print [[</th>
      <td colspan=5><div class="pie-chart" id="topApplicationCategories"></div></td>
    </tr>
    <tr>
      <th class="text-left">]] print(i18n("ndpi_page.live_flows_count")) print [[</th>
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

       do_pie("#topApplicationCategories", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_ndpi_stats.lua', { ndpi_category: "true", ndpistats_mode: "sinceStartup", ifid: "]] print(ifid) print [[" }, "", refresh);

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
     <table id="if_stats_ndpi" class="table table-bordered table-striped tablesorter">
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
setInterval(update_ndpi_table, 5000);

</script>
]]

   
   print [[
     <table id="if_stats_ndpi_categories" class="table table-bordered table-striped tablesorter">
     ]]

   print("<thead><tr><th>" .. i18n("ndpi_page.application_protocol_category") .. "</th><th>" .. i18n("ndpi_page.total_since_startup") .. "</th><th>" .. i18n("percentage") .. "</th></tr></thead>\n")

   print ('<tbody id="if_stats_ndpi_categories_tbody">\n')
   print ("</tbody>")
   print("</table>\n")
   print [[
<script>
function update_ndpi_categories_table() {
  $.ajax({
    type: 'GET',
    url: ']]
   print (ntop.getHttpPrefix())
   print [[/lua/if_stats_ndpi_categories.lua',
    data: { ifid: "]] print(ifid) print [[" },
    success: function(content) {
      $('#if_stats_ndpi_categories_tbody').html(content);
      // Let the TableSorter plugin know that we updated the table
      $('#if_stats_ndpi_categories_tbody').trigger("update");
    }
  });
}
update_ndpi_categories_table();
setInterval(update_ndpi_categories_table, 5000);

</script>
]]

elseif(page == "ICMP") then

  print [[
     <table id="icmp_table" class="table table-bordered table-striped tablesorter">
     <thead><tr><th>]] print(i18n("icmp_page.icmp_message")) print [[</th><th style='text-align:right;'>]] print(i18n("packets")) print[[</th></tr></thead>
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
      $('#icmp_table').trigger("update");
    }
  });
}

update_icmp_table();
setInterval(update_icmp_table, 5000);
</script>

]]
elseif(page == "ARP") then

  print [[
     <table id="arp_table" class="table table-bordered table-striped tablesorter">
     <thead><tr><th>]] print(i18n("arp_page.arp_type")) print [[</th><th style='text-align:right;'>]] print(i18n("packets")) print[[</th></tr></thead>
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
      $('#arp_table').trigger("update");
    }
  });
}

update_arp_table();
setInterval(update_arp_table, 5000);
</script>

]]
   
elseif(page == "historical") then
   local schema = _GET["ts_schema"] or "iface:traffic"
   local selected_epoch = _GET["epoch"] or ""
   local tags = {
      ifid = ifid,
      protocol = _GET["protocol"],
      category = _GET["category"],
   }
   url = url.."&page=historical"

   drawGraphs(ifstats.id, schema, tags, _GET["zoom"], url, selected_epoch, {
      top_protocols = "top:iface:ndpi",
      top_categories = "top:iface:ndpi_categories",
      top_profiles = "top:profile:traffic",
      top_senders = "top:local_senders",
      top_receivers = "top:local_receivers",
      show_historical = true,
      timeseries = {
         {schema="iface:flows",                 label=i18n("graphs.active_flows")},
         {schema="iface:hosts",                 label=i18n("graphs.active_hosts")},
         {schema="custom:flows_vs_local_hosts", label=i18n("graphs.flows_vs_local_hosts"), check={"iface:flows", "iface:local_hosts"}, step=60},
         {schema="custom:flows_vs_traffic",     label=i18n("graphs.flows_vs_traffic"), check={"iface:flows", "iface:traffic"}, step=60},
         {schema="iface:devices",               label=i18n("graphs.active_devices")},
         {schema="iface:http_hosts",            label=i18n("graphs.active_http_servers"), nedge_exclude=1},
         {schema="iface:traffic",               label=i18n("traffic")},
         {schema="iface:packets",               label=i18n("packets")},
         {schema="iface:drops",                 label=i18n("graphs.packet_drops")},
         {schema="iface:nfq_pct",               label=i18n("graphs.num_nfq_pct"), nedge_only=1},

         {schema="iface:zmq_recv_flows",        label=i18n("graphs.zmq_received_flows"), nedge_exclude=1},
         {separator=1, nedge_exclude=1},
         {schema="iface:tcp_lost",              label=i18n("graphs.tcp_packets_lost"), nedge_exclude=1},
         {schema="iface:tcp_out_of_order",      label=i18n("graphs.tcp_packets_ooo"), nedge_exclude=1},
         --{schema="tcp_retr_ooo_lost",   label=i18n("graphs.tcp_retr_ooo_lost"), nedge_exclude=1},
         {schema="iface:tcp_retransmissions",   label=i18n("graphs.tcp_packets_retr"), nedge_exclude=1},
         {separator=1},
         {schema="iface:tcp_syn",               label=i18n("graphs.tcp_syn_packets"), nedge_exclude=1},
         {schema="iface:tcp_synack",            label=i18n("graphs.tcp_synack_packets"), nedge_exclude=1},
         {schema="iface:tcp_finack",            label=i18n("graphs.tcp_finack_packets"), nedge_exclude=1},
         {schema="iface:tcp_rst",               label=i18n("graphs.tcp_rst_packets"), nedge_exclude=1},
      }
   })
elseif(page == "trafficprofiles") then
   print("<table class=\"table table-striped table-bordered\">\n")
   print("<tr><th width=15%><a href=\""..ntop.getHttpPrefix().."/lua/pro/admin/edit_profiles.lua\">" .. i18n("traffic_profiles.profile_name") .. "</A></th><th width=5%>" .. i18n("chart") .. "</th><th>" .. i18n("traffic") .. "</th></tr>\n")
   for pname,pbytes in pairs(ifstats.profiles) do
     local trimmed = trimSpace(pname)
     local statschart_icon = ''

     if ts_utils.exists("profile:traffic", {ifid=ifid}) then
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
  local dump_all_traffic = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_all_traffic')
  local dump_unknown_traffic = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_unknown_traffic')
  local dump_status_tap = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_tap')
  local dump_status_disk = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_disk')

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
  if(dump_unknown_traffic == "true") then
    dump_unknown_checked = 'checked="checked"'
    dump_unknown_value = "false" -- Opposite
  else
    dump_unknown_checked = ""
    dump_unknown_value = "true" -- Opposite
  end
  if(dump_status_tap == "true") then
    dump_traffic_tap_checked = 'checked="checked"'
    dump_traffic_tap_value = "false" -- Opposite
  else
    dump_traffic_tap_checked = ""
    dump_traffic_tap_value = "true" -- Opposite
  end

   print("<form id=\"packetdump_form\" class=\"form-inline\" method=\"post\">")
   print("<table class=\"table table-striped table-bordered\">\n")
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
   print("<tr><th rowspan=2 width=30%>" .. i18n("packetdump_page.packet_dump") .. "</th><td>")
	       print('<input name="dump_all_traffic" type="checkbox" value="1" '..dump_all_traffic_checked..'>'..' '..i18n("packetdump_page.dump_all_traffic"))
	       print('</input>')
   print("</td></tr>\n")

   print("<tr><td>")
	       print('<input name="dump_unknown_to_disk" type="checkbox" value="1" '..dump_unknown_checked..'> '..i18n("packetdump_page.dump_unknown_traffic")..' </input>')
   print("</td></tr>\n")

   print("<tr><th width=30%>" .. i18n("packetdump_page.packet_dump_to_disk").. "</th><td>")
	       print('<input name="dump_traffic_to_disk" type="checkbox" value="1" '..dump_traffic_checked..'> <i class="fa fa-hdd-o fa-lg"></i> '..i18n("packetdump_page.dump_traffic_to_disk"))
	       if(dump_traffic_checked ~= "") then
		 local dumped = interface.getInterfacePacketsDumpedFile()
	         print(" - " .. i18n("packetdump_page.num_dumped_packets",{num_pkts=ternary(dumped, dumped, 0)}))
	       end
	       print('</input>')
   print("</td></tr>\n")

   print("<tr><th>" .. i18n("packetdump_page.packet_dump_to_tap") .. "</th><td>")
   if(interface.getInterfaceDumpTapName() ~= "") then
	       print('<input name="dump_traffic_to_tap" type="checkbox" value="1" '..dump_traffic_tap_checked..'> <i class="fa fa-filter fa-lg"></i> '..i18n("packetdump_page.dump_traffic_to_tap")..' ')
	       print('('..interface.getInterfaceDumpTapName()..')')
	       if(dump_traffic_tap_checked ~= "") then
		 dumped = interface.getInterfacePacketsDumpedTap()
 		 print(" - " .. i18n("packetdump_page.num_dumped_packets",{num_pkts=ternary(dumped, dumped, 0)}))
	       end
	       print(' </input>')
   else
      print(i18n("packetdump_page.packet_dump_to_tap_disabled_message"))
end

   print("</td></tr>\n")
   print("<tr><th width=250>"..i18n("packetdump_page.sampling_rate").."</th>\n")
   print [[<td>]]

   print [[<input type="number" style="width:127px;display:inline;" class="form-control" name="sampling_rate" placeholder="" min="1" step="1" max="100000000" value="]]
   local srate = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_sampling_rate')
   if not isEmptyString(srate) then print(srate) else print("1") end
   print [["></input>
    </td></tr>
       ]]
   

   print("<tr><th colspan=2>" .. i18n("packetdump_page.dump_to_disk_parameters") .. "</th></tr>")
   print("<tr><th width=250>" .. i18n("packetdump_page.pcap_dump_directory") .. "</th><td>")
   pcapdir = dirs.workingdir .."/"..ifstats.id.."/pcap/"
   print(pcapdir.."</td></tr>\n")
   print("<tr><th width=250>" .. i18n("packetdump_page.max_packets_per_file") .. "</th>\n")
   print [[<td>]]
      print [[<input type="number" style="width:127px;display:inline;" class="form-control" name="max_pkts_file" placeholder="" min="1" step="1" max="100000000" value="]]
      local max_pkts_file = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_max_pkts_file')
      if(max_pkts_file ~= nil and max_pkts_file ~= "") then
	 print(max_pkts_file.."")
      else
	 print(interface.getInterfaceDumpMaxPkts().."")
      end
      print [["></input> pkts<br>
    <small>]] print(i18n("packetdump_page.max_packets_per_file_description")) print [[</small>
    </td></tr>
       ]]
   print("<tr><th width=250>" .. i18n("packetdump_page.max_duration_file") .. "</th>\n")
   print [[<td>]]
      print [[<input type="number" class="form-control" style="width:127px;display:inline;" name="max_sec_file" placeholder="" min="60" step="60" max="100000000" value="]]
      local max_sec_file = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_max_sec_file')
      if not isEmptyString(max_sec_file) then
	 print(max_sec_file.."")
      else
	 print(interface.getInterfaceDumpMaxSec().."")
      end
      print [["></input> sec<br>
    <small>]] print(i18n("packetdump_page.max_duration_file_description") .. "<br>") print(i18n("packetdump_page.note") .. ": " .. i18n("packetdump_page.note_max_duration_file")) print[[</small>
    </td></tr>
       ]]
   print("<tr><th width=250>" .. i18n("packetdump_page.max_dump_files") .. "</th>\n")
   print [[<td>]]
      print [[<input type="number" style="width:127px;display:inline;" class="form-control" name="max_files" placeholder="" min="1" step="1" max="500000000" value="]]
      local max_files = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_max_files')
      if not isEmptyString(max_files) then
	 print((max_files / 1e6).."")
      else
	 print(interface.getInterfaceDumpMaxFiles().."")
      end
      print [["></input> MB<br>
    <small>]] print(i18n("packetdump_page.max_size_dump_files_description")) print[[<br>]] print(i18n("packetdump_page.note") .. ": " .. i18n("packetdump_page.note_max_size_dump_files")) print[[</small>
    </td>]]
   print("</table>")
   print[[<button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>]]
   print("</form>")
   print[[<script>
      aysHandleForm("#packetdump_form");
   </script>]]
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
   <form id="iface_config" lass="form-inline" method="post">
   <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   <table class="table table-bordered table-striped">]]

   if ((not interface.isPcapDumpInterface()) and
       (ifstats.name ~= nil) and
       (ifstats.name ~= "dummy")) then
      -- Custom name
      print[[
      <tr>
         <th>]] print(i18n("if_stats_config.custom_name")) print[[</th>
         <td>]]
      local label = getHumanReadableInterfaceName(ifstats.name)
      inline_input_form("custom_name", "Custom Name",
         i18n("if_stats_config.custom_name_popup_msg"),
         label, isAdministrator(), 'autocorrect="off" spellcheck="false"')
      print[[
         </td>
      </tr>]]

      -- Interface speed
      if not have_nedge then
	print[[
	<tr>
	   <th>]] print(i18n("if_stats_config.interface_speed")) print[[</th>
	   <td>]]
	local ifspeed = getInterfaceSpeed(ifstats.id)
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
   end

   if not have_nedge then
     -- Scaling factor
     if interface.isPacketInterface() and not have_nedge then
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
   end

   local rv = ntop.getMembersCache(getHideFromTopSet(ifstats.id)) or {}
   local members = {}

   -- impose sort order
   for _, net in pairsByValues(rv, asc) do
      members[#members + 1] = net
   end

   local hide_top = table.concat(members, ",")

      print[[
	<tr>
	   <th>]] print(i18n("if_stats_config.hide_from_top_networks")) print[[</th>
	   <td>]]

	print('<input style="width:36em;" class="form-control" name="hide_from_top" placeholder="'..i18n("if_stats_config.hide_from_top_networks_descr", {example="192.168.1.1,192.168.100.0/24"})..'" value="' .. hide_top .. '">')

	print[[
	   </td>
	</tr>]]

   -- Alerts
   local trigger_alerts = true
   local trigger_alerts_checked = "checked"

   if _SERVER["REQUEST_METHOD"] == "POST" then
      if _POST["trigger_alerts"] ~= "1" then
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
            <input name="trigger_alerts" type="checkbox" value="1" ]] print(trigger_alerts_checked) print[[>
         </td>
      </tr>]]

   -- per-interface RRD generation
   local interface_rrd_creation = true
   local interface_rrd_creation_checked = "checked"

   if _SERVER["REQUEST_METHOD"] == "POST" then
      if _POST["interface_rrd_creation"] ~= "1" then
         interface_rrd_creation = false
         interface_rrd_creation_checked = ""
      end

      ntop.setPref("ntopng.prefs.ifid_"..ifId..".interface_rrd_creation", tostring(interface_rrd_creation))
   else
      interface_rrd_creation = ntop.getPref("ntopng.prefs.ifid_"..ifId..".interface_rrd_creation")

      if interface_rrd_creation == "false" then
         interface_rrd_creation = false
         interface_rrd_creation_checked = ""
      end
   end

   print [[<tr>
         <th>]] print(i18n("if_stats_config.interface_rrd_creation")) print[[</th>
         <td>
            <input name="interface_rrd_creation" type="checkbox" value="1" ]] print(interface_rrd_creation_checked) print[[>
         </td>
      </tr>]]

   -- per-interface Network Discovery
   if interface.isDiscoverableInterface() then
      local discover = require "discover_utils"

      local interface_network_discovery = true
      local interface_network_discovery_checked = "checked"

      if _SERVER["REQUEST_METHOD"] == "POST" then
	 if _POST["interface_network_discovery"] ~= "1" then
	    interface_network_discovery = false
	    interface_network_discovery_checked = ""
	 end

	 ntop.setPref(discover.getInterfaceNetworkDiscoveryEnabledKey(ifId), tostring(interface_network_discovery))
      else
	 interface_network_discovery = ntop.getPref(discover.getInterfaceNetworkDiscoveryEnabledKey(ifId))

	 if interface_network_discovery == "false" then
	    interface_network_discovery = false
	    interface_network_discovery_checked = ""
	 end
      end

      print [[<tr>
	 <th>]] print(i18n("if_stats_config.interface_network_discovery")) print[[</th>
	 <td>
      <input type="checkbox" name="interface_network_discovery" value="1" ]] print(interface_network_discovery_checked) print[[>
	 </td>
      </tr>]]
   end

      print[[
   </table>
   <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>
   </form>
   <script>
      aysHandleForm("#iface_config");
   </script>]]

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
         $("#snmp_device_link").attr("href", "]] print(ntop.getHttpPrefix()) print[[/lua/pro/enterprise/snmp_device_details.lua?host=" + selected_device);

         snmp_bind_port_ajax = $.ajax({
          type: 'GET',
          url: ']]
   print (ntop.getHttpPrefix())
   print [[/lua/pro/enterprise/get_snmp_device_details.lua',
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
elseif page == "traffic_report" then
   dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/traffic_report.lua")
end

print("<script>\n")
print("var last_pkts  = " .. ifstats.stats.packets .. ";\n")
print("var last_drops = " .. ifstats.stats.drops .. ";\n")

if(ifstats.zmqRecvStats ~= nil) then
   print("var last_zmq_time = 0;\n")
   print("var last_zmq_flows = ".. ifstats.zmqRecvStats.flows .. ";\n")
   print("var last_zmq_events = ".. ifstats.zmqRecvStats.events .. ";\n")
   print("var last_zmq_counters = ".. ifstats.zmqRecvStats.counters .. ";\n")
   print("var last_zmq_msg_drops = ".. ifstats.zmqRecvStats.zmq_msg_drops .. ";\n")

   print("var last_probe_zmq_exported_flows = ".. (ifstats["zmq.num_flow_exports"] or 0) .. ";\n")
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
           $('#if_num_remote_zmq_flow_exports').html(addCommas(rsp["zmq.num_flow_exports"])+" "+get_trend(rsp["zmq.num_flow_exports"], last_probe_zmq_exported_flows));

           last_zmq_flows = rsp.zmqRecvStats.flows;
           last_zmq_events = rsp.zmqRecvStats.events;
           last_zmq_counters = rsp.zmqRecvStats.counters;
           last_zmq_msg_drops = rsp.zmqRecvStats.zmq_msg_drops;
           last_probe_zmq_exported_flows = rsp["zmq.num_flow_exports"];
           last_zmq_time = now;
        }

	$('#if_pkts').html(addCommas(rsp.packets)+"]]

print(" Pkts\");")

if have_nedge and ifstats.type == "netfilter" and ifstats.netfilter then
   local st = ifstats.netfilter

   print("var last_nfq_queue_total = ".. st.nfq.queue_total .. ";\n")
   print("var last_nfq_handling_failed = ".. st.failures.handle_packet .. ";\n")
   print("var last_nfq_enobufs = ".. st.failures.no_buffers .. ";\n")
   
   print[[
        if(rsp.netfilter.nfq.queue_pct > 80) {
          $('#nfq_queue_total').addClass("label label-danger");
        } else {
          $('#nfq_queue_total').removeClass("label label-danger");
        }
	$('#nfq_queue_total').html(fint(rsp.netfilter.nfq.queue_total) + " [" + fint(rsp.netfilter.nfq.queue_pct) + " %]");
        $('#nfq_queue_total_trend').html(get_trend(last_nfq_queue_total, rsp.netfilter.nfq.queue_total));
	$('#nfq_handling_failed').html(fint(rsp.netfilter.failures.handle_packet));
        $('#nfq_handling_failed_trend').html(get_trend(last_nfq_handling_failed, rsp.netfilter.failures.handle_packet));
	$('#nfq_enobufs').html(fint(rsp.netfilter.failures.no_buffers));
        $('#nfq_enobufs_trend').html(get_trend(last_nfq_enobufs, rsp.netfilter.failures.no_buffers));
	$('#num_conntrack_entries').html(fint(rsp.netfilter.nfq.num_conntrack_entries)+ " [" + fint((rsp.netfilter.nfq.num_conntrack_entries*100)/rsp.num_flows) + " %]");
]]
end

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
              .html("[" + Math.round(rsp.flow_export_drops / (rsp.flow_export_count + rsp.flow_export_count) * 100 * 1000) / 1000 + "%]");
          } else {
            $('#exported_flows_drops_pct').addClass("label label-danger").html("[100%]");
          }
        } else {
          $('#exported_flows_drops').removeClass().html("0");
          $('#exported_flows_drops_pct').removeClass().html("[0%]");
        }
]]

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
	$("#icmp_table").tablesorter();
	$("#arp_table").tablesorter();
	$("#if_stats_ndpi").tablesorter();
	$("#if_stats_ndpi_categories").tablesorter();
    }
);
</script>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
