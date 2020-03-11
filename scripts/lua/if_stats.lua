--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
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
local format_utils  = require "format_utils"
local top_talkers_utils = require "top_talkers_utils"
local internals_utils = require "internals_utils"
local page_utils = require("page_utils")

require "lua_utils"
require "prefs_utils"
require "graph_utils"
require "alert_utils"
require "db_utils"

local recording_utils = require "recording_utils"
local companion_interface_utils = require "companion_interface_utils"
local storage_utils = require "storage_utils"

local have_nedge = ntop.isnEdge()

if ntop.isPro() then
   shaper_utils = require("shaper_utils")
end

sendHTTPContentTypeHeader('text/html')

page = _GET["page"]
ifid = _GET["ifid"]

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

ifname_clean = "iface_"..tostring(ifid)
msg = ""

local is_packet_interface = interface.isPacketInterface()
local is_pcap_dump = interface.isPcapDumpInterface()

local ifstats = interface.getStats()

local disaggregation_criterion_key = "ntopng.prefs.dynamic_sub_interfaces.ifid_"..tostring(ifid)..".mode"
local charts_available = areInterfaceTimeseriesEnabled(ifid)

function inline_input_form(name, placeholder, tooltip, value, can_edit, input_opts, input_class)
   if(can_edit) then
      print('<input style="width:12em;" title="'..tooltip..'" '..(input_opts or "")..' class="form-control '..(input_class or "")..'" name="'..name..'" placeholder="'..placeholder..'" value="')
      if(value ~= nil) then print(value.."") end
      print[[">]]
   else
      if(value ~= nil) then print(value) end
   end
end

function inline_select_form(name, keys, values, curval)
   print[[<select class="form-control" style="width:12em; display:inline;" name="]] print(name) print[[">]]
   for idx, k in ipairs(keys) do
      local v = values[idx]
      print[[<option value="]] print(v) print[[" ]]

      if curval == v then
         print("selected")
      end

      print[[>]] print(k) print[[</option>]]
   end
   print[[</select>]]
end

-- this is a user-browseable page, so we must return counters from
-- the latest reset as the user may have chosen to reset statistics at some point
if ifstats.stats and ifstats.stats_since_reset then
   -- override stats with the values calculated from the latest user reset
   for k, v in pairs(ifstats.stats_since_reset) do
      ifstats.stats[k] = v
   end
end

if ifstats.zmqRecvStats and ifstats.zmqRecvStats_since_reset then
   -- override stats with the values calculated from the latest user reset
   for k, v in pairs(ifstats.zmqRecvStats_since_reset) do
      ifstats.zmqRecvStats[k] = v
   end
end

local ext_interfaces = {}

-- refresh traffic recording availability as one may have installed n2disk
-- with a running instance of ntopng
recording_utils.checkAvailable()

if recording_utils.isAvailable() and recording_utils.isSupportedZMQInterface(ifid) then
   ext_interfaces = recording_utils.getExtInterfaces(ifid)
end

if (isAdministrator()) then
   if (page == "config") and (not table.empty(_POST)) then
      local custom_name = _POST["custom_name"]

      if starts(custom_name, "tcp:__") then
        -- Was mangled by sanitization
        custom_name = "tcp://" .. string.sub(custom_name, 7)
      end

      -- TODO move keys to new schema: replace ifstats.name with ifid
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.name', custom_name)

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
            local address, prefix, vlan = splitNetworkWithVLANPrefix(net)

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
      ntop.setCache("ntopng.prefs.iface_" .. tostring(ifid)..'.scaling_factor',tostring(sf))
      interface.loadScalingFactorPrefs()
   end
end

page_utils.set_active_menu_entry(page_utils.menu_entries.interface, { ifname=getHumanReadableInterfaceName(if_name) })

print("<link href=\""..ntop.getHttpPrefix().."/css/tablesorted.css\" rel=\"stylesheet\">")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print(msg)

if _SERVER["REQUEST_METHOD"] == "POST" and _POST["companion_interface"] ~= nil then
   companion_interface_utils.setCompanion(ifstats.id, _POST["companion_interface"])
end

if _SERVER["REQUEST_METHOD"] == "POST" and _POST["disaggregation_criterion"] ~= nil then
   if _POST["disaggregation_criterion"] == "none" then
      ntop.delCache(disaggregation_criterion_key)
   else
      ntop.setCache(disaggregation_criterion_key, _POST["disaggregation_criterion"])
   end
end

if _SERVER["REQUEST_METHOD"] == "POST" and not isEmptyString(_POST["traffic_recording_provider"]) then
   local prev_provider = recording_utils.getCurrentTrafficRecordingProvider(ifstats.id)

   -- if the current provider is the builtin ntopng and we are changing to another provider
   -- then it may be necessary to stop the builtin ntopng
   if prev_provider == "ntopng" and _POST["traffic_recording_provider"] ~= "ntopng" then
      recording_utils.stop(ifstats.id)
      ntop.setCache('ntopng.prefs.ifid_'..ifstats.id..'.traffic_recording.enabled', "false")
   end

   recording_utils.setCurrentTrafficRecordingProvider(ifstats.id, _POST["traffic_recording_provider"])
end

local has_traffic_recording_page =  (recording_utils.isAvailable()
	  and (interface.isPacketInterface()
		  or ((recording_utils.isSupportedZMQInterface(ifid) and not table.empty(ext_interfaces)))
		  or (recording_utils.getCurrentTrafficRecordingProvider(ifid) ~= "ntopng")))

local dismiss_recording_providers_reminder = recording_utils.isExternalProvidersReminderDismissed(ifstats.id)

local num_pool_hosts = ifstats.num_members.num_hosts
if ifstats.num_members_per_pool[host_pools_utils.DEFAULT_POOL_ID] then
   -- don't show unassigned hosts in the counter
   num_pool_hosts = num_pool_hosts - ifstats.num_members_per_pool[host_pools_utils.DEFAULT_POOL_ID].num_hosts
end


local url = ntop.getHttpPrefix()..'/lua/if_stats.lua?ifid=' .. ifid

--  Added global javascript variable, in order to disable the refresh of pie chart in case
--  of historical interface
print('\n<script>var refresh = '..getInterfaceRefreshRate(ifstats.id)..' * 1000; /* ms */;</script>\n')

local short_name = getHumanReadableInterfaceName(ifname)
local title = i18n("interface") .. ": " .. short_name
   page_utils.print_navbar(title, url,
			   {
			      {
				 hidden = only_historical,
				 active = page == "overview" or page == nil,
				 page_name = "overview",
				 label = "<i class=\"fas fa-lg fa-home\"></i>",
			      },
			      {
				 hidden = not interface.isPacketInterface() or ntop.isnEdge() or interface.isView(),
				 active = page == "networks",
				 page_name = "networks",
				 label = i18n("networks"),
			      },
			      {
				 hidden = not ifstats or ifstats.stats.packets == 0 or ntop.isnEdge(),
				 active = page == "packets",
				 page_name = "packets",
				 label = i18n("packets"),
			      },
			      {
				 active = page == "ndpi",
				 page_name = "ndpi",
				 label = i18n("applications"),
			      },
			      {
				 hidden = ntop.isnEdge(),
				 active = page == "ICMP",
				 page_name = "ICMP",
				 label = i18n("icmp"),
			      },
			      {
				 hidden = not ifstats or not ifstats["has_macs"] or ntop.isnEdge(),
				 active = page == "ARP",
				 page_name = "ARP",
				 label = i18n("arp"),
			      },
			      {
				 hidden = not charts_available,
				 active = page == "historical",
				 page_name = "historical",
				 label = "<i class='fas fa-lg fa-chart-area'></i>",
			      },
			      {
				 hidden = have_nedge or not ifstats or not ifstats.profiles,
				 active = page == "trafficprofiles",
				 page_name = "trafficprofiles",
				 label = "<i class=\"fas fa-lg fa-user-md\"></i>",
			      },
			      {
				 hidden = not has_traffic_recording_page,
				 active = page == "traffic_recording",
				 page_name = "traffic_recording",
				 label = "<i class=\"fas fa-lg fa-hdd\"></i>",
			      },
			      {
				 hidden = not isAdministrator() or not areAlertsEnabled(),
				 active = page == "alerts",
				 page_name = "alerts",
				 label = "<i class=\"fas fa-lg fa-exclamation-triangle\"></i>",
			      },
			      {
				 hidden = not hasTrafficReport(),
				 active = page == "traffic_report",
				 page_name = "traffic_report",
				 label = "<i class='fas fa-lg fa-file-alt report-icon'></i>",
			      },
			      {
				 hidden = not isAdministrator() or is_pcap_dump,
				 active = page == "config",
				 page_name = "config",
				 label = "<i class=\"fas fa-lg fa-cog\"></i></a></li>",
			      },
			      {
				 active = page == "internals",
				 page_name = "internals",
				 label = "<i class=\"fas fa-lg fa-wrench\"></i>",
			      },
			      {
				 hidden = not isAdministrator() or not ntop.isEnterprise() or ifstats.isDynamic or ifstats.isView,
				 active = page == "sub_interfaces",
				 page_name = "sub_interfaces",
				 label = "<i class=\"fas fa-lg fa-code-branch\"></i>",
			      },
			      {
				 hidden = not isAdministrator() or have_nedge,
				 active = page == "pools",
				 page_name = "pools",
				 label = "<i class=\"fas fa-lg fa-users\"></i>",
				 badge_num = num_pool_hosts,
			      },
			      {
				 hidden = not isAdministrator() or is_pcap_dump,
				 active = page == "dhcp",
				 page_name = "dhcp",
				 label = "<i class=\"fas fa-lg fa-bolt\"></i>",
			      },
			   }
   )

if((page == "overview") or (page == nil)) then
   local tags = {ifid = ifstats.id}
   print("<table class=\"table table-striped table-bordered\">\n")
   print("<tr><th width=15%>"..i18n("if_stats_overview.id").."</th><td colspan=6>" .. ifstats.id .. " ")
   if(ifstats.description ~= ifstats.name) then print(" ("..ifstats.description..")") end
   print("</td></tr>\n")

   if not is_pcap_dump and ifstats["type"] ~= "netfilter" then
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
	 remote_probe_public_ip = "<b>"..i18n("if_stats_overview.public_probe_ip").."</b>: <A HREF=\"http://"..ifstats["probe.public_ip"].."\">"..ifstats["probe.public_ip"].."</A> <i class='fas fa-external-link-alt'></i></td>\n"
      end

      if not isEmptyString(ifstats["zmq.num_flow_exports"]) then
	 num_remote_flow_exports = "<b>"..i18n("if_stats_overview.probe_zmq_num_flow_exports").."</b>: <span id=if_num_remote_zmq_flow_exports>"..formatValue(ifstats["zmq.num_flow_exports"]).."</span>"
      end

      if not isEmptyString(ifstats["zmq.num_exporters"]) then
	 num_remote_flow_exporters = "<b>"..i18n("if_stats_overview.probe_zmq_num_endpoints").."</b>: <span id=if_num_remote_zmq_exporters>"..formatValue(ifstats["zmq.num_exporters"]).."</span>"
      end

      local remote_ifname = ''
      if ifstats["remote.name"] == "none" then
	 remote_ifname = i18n("if_stats_overview.remote_probe_collector_mode")
      else
	 remote_ifname = string.format("<b>%s</b>: %s [%s]", i18n("if_stats_overview.interface_name"), ifstats["remote.name"], bitsToSize(ifstats.speed*1000000))
      end

      print("<tr><th rowspan=3>"..i18n("if_stats_overview.remote_probe").."</th><td nowrap>"..remote_ifname.."</td>")
      print("<td nowrap>"..remote_if_addr.."</td>")
      print("<td nowrap>"..remote_probe_ip.."</td>")
      print("<td nowrap colspan=2>"..remote_probe_public_ip.."</td>\n")
      print("</tr>\n")

      print("<tr>")
      local colspan = 4

      if ifstats["timeout.lifetime"] > 0 then
	 print("<td nowrap><b>"..i18n("if_stats_overview.probe_timeout_lifetime").."</b>: "..secondsToTime(ifstats["timeout.lifetime"]).."</td>")
      else
	 colspan = colspan - 1
      end
      if ifstats["timeout.idle"] > 0 then
	 print("<td nowrap><b>"..i18n("if_stats_overview.probe_timeout_idle").."</b>: "..secondsToTime(ifstats["timeout.idle"]).."</td>")
      else
	 colspan = colspan - 1
      end

      print("<td nowrap colspan="..colspan..">"..num_remote_flow_exporters.."</td>")
      print("</tr>")

      local has_drops_export_queue_full = (tonumber(ifstats["zmq.drops.export_queue_full"]) and tonumber(ifstats["zmq.drops.export_queue_full"]) > 0)
      local has_drops_flow_collection_drops = (tonumber(ifstats["zmq.drops.flow_collection_drops"]) or 0) > 0
      local has_drops_flow_collection_udp_socket_drops = (tonumber(ifstats["zmq.drops.flow_collection_udp_socket_drops"]) or 0) > 0
      local has_remote_drops = (has_drops_export_queue_full or has_drops_flow_collection_drops)

      if not has_remote_drops then
	 print('<tr style="display: none;">')
      else
	 print("<tr>")
	 local export_queue_full, flow_collection_drops
	 local colspan = 6

	 if has_drops_export_queue_full then
	    local num_full = tonumber(ifstats["zmq.drops.export_queue_full"])
	    local span_class = ' '
	    if num_full > 0 then
	       span_class = 'class="badge badge-danger"'
	    end
	    export_queue_full = "<b>"..i18n("if_stats_overview.probe_zmq_drops_export_queue_full").." <sup><i class='fas fa-info-circle' title='"..i18n("if_stats_overview.note_probe_zmq_drops_export_queue_full").."'></i></sup></b>: <span "..span_class.." id=if_zmq_drops_export_queue_full>"..formatValue(ifstats["zmq.drops.export_queue_full"]).."</span>"
	 end

	 if has_drops_flow_collection_drops then
	    local num_full = tonumber(ifstats["zmq.drops.flow_collection_drops"])
	    local span_class = ' '
	    if num_full > 0 then
	       span_class = 'class="badge badge-danger"'
	    end
	    flow_collection_drops = "<b>"..i18n("if_stats_overview.probe_zmq_drops_flow_collection_drops").." <sup><i class='fas fa-info-circle' title='"..i18n("if_stats_overview.note_probe_zmq_drops_flow_collection_drops").."'></i></sup></b>: <span "..span_class.." id=if_zmq_drops_flow_collection_drops>"..formatValue(ifstats["zmq.drops.flow_collection_drops"]).."</span>"
	 end

	 if has_drops_flow_collection_udp_socket_drops then
	    local num_full = tonumber(ifstats["zmq.drops.flow_collection_udp_socket_drops"])
	    local span_class = ' '
	    if num_full > 0 then
	       span_class = 'class="badge badge-danger"'
	    end
	    flow_collection_udp_socket_drops = "<b>"..i18n("if_stats_overview.probe_zmq_drops_flow_collection_udp_socket_drops").." <sup><i class='fas fa-info-circle' title='"..i18n("if_stats_overview.note_probe_zmq_drops_flow_collection_udp_socket_drops").."'></i></sup></b>: <span "..span_class.." id=if_zmq_drops_flow_collection_udp_socket_drops>"..formatValue(ifstats["zmq.drops.flow_collection_udp_socket_drops"]).."</span>"
	 end

	 if export_queue_full then
	    print("<td>"..export_queue_full.."</td>")
	    colspan = colspan - 1
	 end
	 if flow_collection_drops then
	    print("<td>"..flow_collection_drops.."</td>")
	    colspan = colspan - 1
	 end
	 if flow_collection_udp_socket_drops then
	    print("<td>"..flow_collection_udp_socket_drops.."</td>")
	    colspan = colspan - 1
	 end
	 if colspan then
	    print("<td colspan="..colspan.."></td>")
	 end
      end

      print("</tr>")
   end

   local is_physical_iface = (interface.isPacketInterface()) and (not is_pcap_dump)

   local label = getHumanReadableInterfaceName(ifstats.name)
   local s
   if ((not isEmptyString(label)) and (label ~= ifstats.name)) then
      s = label.." (" .. ifstats.name .. ")"
   else
      s = ifstats.name
   end

   if((isAdministrator()) and (not is_pcap_dump)) then
      s = s .. " <a href=\""..url.."&page=config\"><i class=\"fas fa-cog fa-sm\" title=\"Configure Interface Name\"></i></a>"
   end

   print('<tr><th width="250">'..i18n("name")..'</th><td colspan="2">' .. s ..' </td>\n')

   print("<th>"..i18n("if_stats_overview.family").."</th><td colspan=2>")
   print(ifstats.type)

   if(ifstats.inline) then
      print(" "..i18n("if_stats_overview.in_path_interface"))
   end

   if(ifstats.has_traffic_directions) then
      print(" ".. i18n("if_stats_overview.has_traffic_directions") .. " ")
   end
   print("</tr>")

   if ifstats.encryption and ifstats.encryption.public_key then
      print("<tr><th width=250>"..i18n("if_stats_overview.zmq_encryption_public_key").."</th><td colspan=6><span>")
      print(ifstats.encryption.public_key)
      print("<br><small><b>"..i18n("if_stats_overview.note").."</b>:<ul><li> ".. i18n("if_stats_overview.zmq_encryption_public_key_note", {key="&lt;key&gt;"}).."")
      print("<li>nprobe --zmq-encryption-key '"..ifstats.encryption.public_key.."' ...")
      print("</small></ul></td></tr>\n")
   end

   if is_physical_iface then
      print("<tr>")
      print("<th>"..i18n("mtu").."</th><td colspan=2  nowrap>"..ifstats.mtu.." "..i18n("bytes").."</td>\n")
      local speed_key = 'ntopng.prefs.'..ifname..'.speed'
      local speed = ntop.getCache(speed_key)
      if (tonumber(speed) == nil) then
	 speed = ifstats.speed
      end
      print("<th width=250>"..i18n("speed").."</th><td colspan=2>" .. bitsToSize(speed * 1000000) .. "</td>")
      print("</tr>")
   end

   if (not hasAllowedNetworksSet()) and ((ifstats.num_alerts_engaged > 0) or (ifstats.num_dropped_alerts > 0)) then
      print("<tr>")
      local warning = "<i class='fas fa-exclamation-triangle fa-lg' style='color: #B94A48;'></i> "

      print("<th>".. ternary(ifstats.num_alerts_engaged > 0, warning, "") ..i18n("show_alerts.engaged_alerts")..
	       ternary(charts_available, " <A HREF='"..url.."&page=historical&ts_schema=iface:alerts_stats'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td colspan=2  nowrap><a href='".. ntop.getHttpPrefix() .."/lua/show_alerts.lua?ifid="..ifstats.id.."'>".. formatValue(ifstats.num_alerts_engaged) .."</a> <span id=engaged_alerts_trend></span></td>\n")
      print("<th width=250>".. ternary(ifstats.num_dropped_alerts > 0, warning, "")..i18n("show_alerts.dropped_alerts")..
	       " <i class='fas fa-sm fa-info-circle' title='".. i18n("if_stats_overview.dropped_alerts_info") .."'></i>"..
	       ternary(charts_available, " <A HREF='"..url.."&page=historical&ts_schema=iface:alerts_stats'><i class='fas fa-chart-area fa-sm'></i></A>", "")
	       .."</th><td colspan=2>" .. formatValue(ifstats.num_dropped_alerts) .. " <span id=dropped_alerts_trend></span></td>\n</td>")
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

      print("<tr><th nowrap>"..i18n("if_stats_overview.collected_flows")..ternary(charts_available, " <A HREF='"..url.."&page=historical&ts_schema=iface:zmq_recv_flows'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td width=20%><span id=if_zmq_flows>"..formatValue(ifstats.zmqRecvStats.flows).."</span></td>")

      print("<th nowrap>"..i18n("if_stats_overview.interface_rx_updates").."</th><td width=20%><span id=if_zmq_events>"..formatValue(ifstats.zmqRecvStats.events).."</span></td>")

      print("<th nowrap>"..i18n("if_stats_overview.sflow_counter_updates").."</th><td width=20%><span id=if_zmq_counters>"..formatValue(ifstats.zmqRecvStats.counters).."</span></td></tr>")

      print("<tr><th nowrap>"..i18n("if_stats_overview.zmq_message_rcvd")..ternary(charts_available, " <A HREF='"..url.."&page=historical&ts_schema=custom:zmq_msg_rcvd_vs_drops'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td width=20%><span id=if_zmq_msg_rcvd>"..formatValue(ifstats.zmqRecvStats.zmq_msg_rcvd).."</span></td>")

      print("<th nowrap> <i class='fas fa-tint' aria-hidden='true'></i> "..i18n("if_stats_overview.zmq_message_drops")..ternary(charts_available, " <A HREF='"..url.."&page=historical&ts_schema=custom:zmq_msg_rcvd_vs_drops'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td width=20%><span id=if_zmq_msg_drops>"..formatValue(ifstats.zmqRecvStats.zmq_msg_drops).."</span></td>")
      print("<th nowrap> "..i18n("if_stats_overview.zmq_avg_msg_flows").."</th><td width=20%><span id=if_zmq_avg_msg_flows></span></td></tr>")
   end

   print("<tr><th colspan=7 nowrap>"..i18n("if_stats_overview.traffic_statistics").."</th></tr>\n")

   print("<tr><th nowrap>"..i18n("report.total_traffic")..ternary(charts_available, " <A HREF='"..url.."&page=historical&ts_schema=iface:traffic'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td width=20%><span id=if_bytes>"..bytesToSize(ifstats.stats.bytes).."</span> [<span id=if_pkts>".. formatValue(ifstats.stats.packets) .. " ".. label .."</span>] ")

   print("<span id=pkts_trend></span></td>")

   if not ifstats.isDynamic then
      print("<th width=20%><span id='if_packet_drops_drop'><i class='fas fa-tint' aria-hidden='true'></i></span> ")

      print(i18n("if_stats_overview.dropped_packets")..ternary(charts_available, " <A HREF='"..url.."&page=historical&ts_schema=iface:packets_vs_drops'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th>")

      print("<td width=20% colspan=3><span id=if_drops>")

      if(ifstats.stats.drops > 0) then
	 print('<span class="badge badge-danger">')
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

   if(ifstats.has_traffic_directions) then
      print("<tr><th nowrap>"..i18n("http_page.traffic_sent")..ternary(charts_available, " <A HREF='"..url.."&page=historical&ts_schema=iface:traffic_rxtx'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td width=20%><span id=if_out_bytes>"..bytesToSize(ifstats.eth.egress.bytes).."</span> [<span id=if_out_pkts>".. formatValue(ifstats.eth.egress.packets) .. " ".. label .."</span>] <span id=pkts_out_trend></span></td>")
      print("<th nowrap>"..i18n("http_page.traffic_received")..ternary(charts_available, " <A HREF='"..url.."&page=historical&ts_schema=iface:traffic_rxtx'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td width=20%><span id=if_in_bytes>"..bytesToSize(ifstats.eth.ingress.bytes).."</span> [<span id=if_in_pkts>".. formatValue(ifstats.eth.ingress.packets) .. " ".. label .."</span>] <span id=pkts_in_trend></span><td></td></tr>")
   end
  
   if not interface.isPacketInterface() then 
      local external_json_stats = ntop.getCache("ntopng.prefs.ifid_"..tostring(ifid)..".external_stats")
      if not isEmptyString(external_json_stats) then
         local external_stats = json.decode(external_json_stats)
         if external_stats ~= nil then
            local external_stats_title = i18n("external_stats.title")
            if external_stats.i18n_title then
              external_stats_title = i18n(external_stats.i18n_title)
              external_stats.i18n_title = nil
            end
            print("<tr><th colspan=7 nowrap>"..external_stats_title.."</th></tr>\n")
            for key, value in pairsByKeys(external_stats, asc) do
               print("<tr>")
               print("<th nowrap>"..ternary(i18n("external_stats."..key), i18n("external_stats."..key), key).."</th>")
               print("<td colspan=4>"..ternary(type(value) == "number", formatValue(value), value).."</td>")
               print("</tr>")
            end
         end
      end
   end

   if(prefs.is_dump_flows_enabled and ifstats.isView == false) then
      local dump_to = "MySQL"
      if prefs.is_dump_flows_to_es_enabled == true then
	 dump_to = "ElasticSearch"
      end
      if prefs.is_dump_flows_to_ls_enabled == true then
	 dump_to = "Logstash"
      end
      if prefs.is_nindex_enabled == true then
	 dump_to = "nIndex"
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

      print("<th><span id='if_flow_drops_drop'<i class='fas fa-tint' aria-hidden='true'></i></span> ")
      print(i18n("if_stats_overview.dropped_flows").."</th>")

      local span_danger = ""
      if export_drops == nil then


      elseif(export_drops > 0) then
	 span_danger = ' class="badge badge-danger"'
      end
      print("<td><span id=exported_flows_drops "..span_danger..">"..formatValue(export_drops).."</span>&nbsp;")
      print("<span id=exported_flows_drops_pct "..span_danger..">["
	       ..formatValue(round(export_drops_pct, 2)).."%]</span></td>")
      print("<td colspan=3>&nbsp;</td>")
      print("</tr>")
   end

   if ifstats.stats.discarded_probing_packets then
      print("<tr><td colspan=2></td><th nowrap> <i class='fas fa-trash' aria-hidden='true'></i> "..i18n("if_stats_overview.discarded_probing_traffic")..ternary(charts_available, " <A HREF='"..url.."&page=historical&ts_schema=iface:disc_prob_pkts'><i class='fas fa-chart-area fa-sm'></i></A>", "").."</th><td colspan=4width=20%><span id=if_discarded_probing_bytes>"..bytesToSize(ifstats.stats.discarded_probing_bytes).."</span> [<span id=if_discarded_probing_pkts>".. formatPackets(ifstats.stats.discarded_probing_packets) .."</span>] ")

      print("<span id=if_discarded_probing_trend></span></td></tr>\n")
   end

   if isAdministrator() and ifstats.isView == false then
      local ts_utils = require "ts_utils_core"
      local storage_info = storage_utils.interfaceStorageInfo(ifid)
      local storage_items = {}

      if storage_info then
	 if ts_utils.getDriverName() == "rrd" then
	    if storage_info.rrd ~= nil and storage_info.rrd > 0 then
	       table.insert(storage_items, {
			       title = i18n("if_stats_overview.rrd_timeseries"),
			       value = storage_info.rrd,
			       class = "primary",
	       })
	    end
	 end

	 if storage_info.flows ~= nil and storage_info.flows > 0 then
	    table.insert(storage_items, {
			    title = i18n("flows"),
			    value = storage_info.flows,
			    class = "info",
	    })
	 end

	 if storage_info.pcap ~= nil and storage_info.pcap > 0 then
	    local link = nil

	    if recording_utils.isAvailable(ifstats.id) then
	       link = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. ifid .. "&page=traffic_recording"
	    end

	    table.insert(storage_items, {
			    title = i18n("traffic_recording.packet_dumps"),
			    value = storage_info.pcap,
			    class = "warning",
			    link = link
	    })
	 end

	 if #storage_items > 0 then
	    print("<tr><th>"..i18n("traffic_recording.storage_utilization").."</th><td colspan=5>")
	    print(stackedProgressBars(storage_info.total, storage_items, nil, bytesToSize))
	    print("</td></tr>\n")
	 end
      end
   end

   if (ntop.isPcapDownloadAllowed() and ifstats.isView == false and ifstats.isDynamic == false and interface.isPacketInterface()) then
      print("<tr><th>"..i18n("download").."&nbsp;<i class=\"fas fa-download fa-lg\"></i></th><td colspan=2>")

      local live_traffic_utils = require("live_traffic_utils")
      live_traffic_utils.printLiveTrafficForm(ifId)

      print("</td><td colspan=3></td></tr>\n")
   end

   if isAdministrator() then
      print("<tr><th width=250>"..i18n("if_stats_overview.reset_counters").."</th>")
      print("<td colspan=5>")

      local tot	= ifstats.stats.bytes + ifstats.stats.packets + ifstats.stats.drops
      if(ifstats.stats.flow_export_count ~= nil) then
	 tot = tot + ifstats.stats.flow_export_count + ifstats.stats.flow_export_drops
      end

      print('<button id="btn_reset_all" type="button" class="btn btn-secondary" onclick="resetInterfaceCounters(false);">'..i18n("if_stats_overview.all_counters")..'</button>&nbsp;')

      print('<button id="btn_reset_drops" type="button" class="btn btn-secondary" onclick="resetInterfaceCounters(true);">'..i18n("if_stats_overview.drops_only")..'</button>')
      print("</td>")

      print("</tr>\n")
   end

   if have_nedge and ifstats.type == "netfilter" and ifstats.netfilter then
      local st = ifstats.netfilter

      print("<tr><th nowrap>"..i18n("if_stats_overview.nf_queue_total").."</th>")
      local span_class = ''
      if st.nfq.queue_pct > 80 then
	 span_class = "class='badge badge-danger'"
      end
      print("<td width=20%><span id=nfq_queue_total "..span_class..">"..string.format("%s [%s %%]", formatValue(st.nfq.queue_total), formatValue(st.nfq.queue_pct)).." </span> <span id=nfq_queue_total_trend></span></td>")
      print("<th nowrap>"..i18n("if_stats_overview.nf_handle_packet_failed").."</th>")
      print("<td width=20%><span id=nfq_handling_failed>"..formatValue(st.failures.handle_packet).."</span> <span id=nfq_handling_failed_trend></span></td>")
      print("<th nowrap>"..i18n("if_stats_overview.nf_enobufs").."</th>")
      print("<td width=20%><span id=nfq_enobufs>"..formatValue(st.failures.no_buffers).."</span> <span id=nfq_enobufs_trend></span></td>")
      print("</tr>")

      print("<tr><th nowrap>") print(i18n("if_stats_overview.conntrack_flow_entries")) print("</th><td colspan=5>")
      print("<span id=num_conntrack_entries>"..formatValue(st.nfq.num_conntrack_entries).."</span></td>")
      print("</tr>")
   end

   print [[
   <tr><td colspan=7> <small> <b>]] print(i18n("if_stats_overview.note").."</b>:<p>"..i18n("if_stats_overview.note_packets")) print[[</small> </td></tr>
   ]]

   print("</table>\n")

elseif page == "networks" and interface.isPacketInterface() then
   print("<table class=\"table table-striped table-bordered\">")

   if(ifstats.ip_addresses ~= "") then
      local tokens = split(ifstats.ip_addresses, ",")

      if(tokens ~= nil) then
	 print("<tr><th width=250>"..i18n("ip_address").."</th><td colspan=5><ul><li>")
	 local addresses = {}

	 for _,s in pairs(tokens) do
	    t = string.split(s, "/")
	    host = interface.getHostInfo(t[1])

	    if(host ~= nil) then
	       addresses[#addresses+1] = "<a href=\""..ntop.getHttpPrefix().."/lua/host_details.lua?host="..t[1].."\">".. t[1].."</a>".."/"..t[2]
	    else
	       addresses[#addresses+1] = s
	    end
	 end

	 print(table.concat(addresses, "\n<li>"))

	 print("</ul></td></tr>")
      end
   end

   local has_ghost_networks = false
   local ghost_icon = '<font color=red><i class="fas fa-ghost" aria-hidden="true"></i></font>'
   if ifstats.bcast_domains and table.len(ifstats.bcast_domains) > 0 then
      print("<tr><th width=250>"..i18n("broadcast_domain").."</th><td colspan=5>")

      local bcast_domains = {}
      for bcast_domain, domain_info in pairsByKeys(ifstats.bcast_domains) do
	 bcast_domain = string.format("<a href='%s/lua/hosts_stats.lua?network_cidr=%s'>%s</a>", ntop.getHttpPrefix(), bcast_domain, bcast_domain)

	 if domain_info.ghost_network then
	    has_ghost_networks = true
	    bcast_domain = bcast_domain..' '..ghost_icon
	 end

	 bcast_domains[#bcast_domains + 1] = bcast_domain
      end

      if #bcast_domains > 0 then
	 print("<ul>")
	 for _, bcast_domain in ipairs(bcast_domains) do
	    print("<li>"..bcast_domain.."</li>")
	 end
	 print("</ul>")
      end

      print("</td></tr>")
   end
   print("</table>")

   print("<p><b>"..i18n("if_stats_overview.note").."</b>:<ul>")
   print("<li>"..i18n("if_stats_networks.note_iface_addresses").."</li>")
   print("<li>"..i18n("if_stats_networks.note_iface_bcast_domains").."</li>")

   if has_ghost_networks then
      print("<li>"..i18n("if_stats_networks.note_ghost_bcast_domains", {ghost_icon = ghost_icon}).."</li>")
   end
   print("</ul>")

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
  	 <tr ]] print(nedge_hidden) print[[><th class="text-left">]] print(i18n("packets_page.version_vs_flags_distribution")) print[[</th>
<td colspan=1><div class="pie-chart" id="ipverDistro"></div></td><td colspan=1><div class="pie-chart" id="flagsDistro"></div></td></tr>
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
print[[
  <ul id="ndpiNav" class="nav nav-tabs" role="tablist">
    <li class="nav-item active"><a class="nav-link active" data-toggle="tab" role="tab" href="#applications" active>]] print(i18n("applications")) print[[</a></li>
    <li class="nav-item"><a class="nav-link" data-toggle="tab" role="tab" href="#categories">]] print(i18n("categories")) print[[</a></li>
  </ul>
  <div class="tab-content">
    <div id="applications" class="tab-pane in active">
      <br>
      <table class="table table-bordered table-striped">
]]

   if ntop.isPro() and ifstats["custom_apps"] then
      print[[
        <tr>
          <th class="text-left">]] print(i18n("ndpi_page.overview", {what = i18n("ndpi_page.custom_applications")})) print [[</th>
          <td colspan=5><div class="pie-chart" id="topCustomApps"></td>
        </tr>
]]
   end

   print[[
        <tr>
          <th class="text-left">]] print(i18n("ndpi_page.overview", {what = i18n("applications")})) print [[</th>
          <td colspan=3><div class="pie-chart" id="topApplicationProtocols"></td>
          <td colspan=2><div class="pie-chart" id="topApplicationBreeds"></td>
        </tr>
        <tr>
          <th class="text-left">]] print(i18n("ndpi_page.live_flows_count")) print [[</th>
          <td colspan=3><div class="pie-chart" id="topFlowsCount"></td>
          <td colspan=2><div class="pie-chart" id="topTCPFlowsStats">
          <br><small><b>]] print(i18n("ndpi_page.note")) print [[ :</b>]] print(i18n("ndpi_page.note_live_flows_chart")) print [[
          </td>
        </tr>
      </table>
     <table id="if_stats_ndpi" class="table table-bordered table-striped tablesorter">
       <thead>
         <tr>
           <th>]] print(i18n("application")) print[[</th>
           <th>]] print(i18n("ndpi_page.total_since_startup")) print[[</th>
           <th>]] print(i18n("percentage")) print[[</th>
         </tr>
       </thead>
       <tbody id="if_stats_ndpi_tbody"></tbody>
     </table>
    </div>
    <div id="categories" class="tab-pane">
      <br>
      <table class="table table-bordered table-striped">
        <tr>
          <th class="text-left">]] print(i18n("ndpi_page.overview", {what = i18n("categories")})) print [[</th>
          <td colspan=5><div class="pie-chart" id="topApplicationCategories"></td>
        </tr>
      </table>
     <table id="if_stats_ndpi_categories" class="table table-bordered table-striped tablesorter">
       <thead>
         <tr>
           <th>]] print(i18n("category")) print[[</th>
           <th>]] print(i18n("ndpi_page.total_since_startup")) print[[</th>
           <th>]] print(i18n("percentage")) print[[</th>
         </tr>
       </thead>
       <tbody id="if_stats_ndpi_categories_tbody"></tbody>
     </table>
    </div>
]]

print [[
<script type="text/javascript" src="]] print(ntop.getHttpPrefix()) print [[/js/jquery.tablesorter.js"></script>
	<script type='text/javascript'>
	 window.onload=function() {]]

   if ntop.isPro() and ifstats["custom_apps"] then
      print[[do_pie("#topCustomApps", ']]
      print (ntop.getHttpPrefix())
      print [[/lua/pro/get_custom_app_stats.lua', { ifid: "]] print(ifid) print [[" }, "", refresh);
]]
   end

   print[[do_pie("#topApplicationProtocols", ']]
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

function update_ndpi_table() {
  $.ajax({
    type: 'GET',
    url: ']]
   print (ntop.getHttpPrefix())
   print [[/lua/if_stats_ndpi.lua',
    data: { ifid: "]] print(ifid) print [[" },
    success: function(content) {
      if(content) {
         $('#if_stats_ndpi_tbody').html(content);
         // Let the TableSorter plugin know that we updated the table
         $('#if_stats_ndpi_tbody').trigger("update");
      }
    }
  });
}
update_ndpi_table();
setInterval(update_ndpi_table, 5000);

function update_ndpi_categories_table() {
  $.ajax({
    type: 'GET',
    url: ']]
   print (ntop.getHttpPrefix())
   print [[/lua/if_stats_ndpi_categories.lua',
    data: { ifid: "]] print(ifid) print [[" },
    success: function(content) {
      if(content) {
         $('#if_stats_ndpi_categories_tbody').html(content);
         // Let the TableSorter plugin know that we updated the table
         $('#if_stats_ndpi_categories_tbody').trigger("update");
      }
    }
  });
}
update_ndpi_categories_table();
setInterval(update_ndpi_categories_table, 5000);

</script>
]]

elseif(page == "ICMP") then
print[[
  <ul id="icmp_nav" class="nav nav-tabs" role="tablist">
    <li class="nav-item active"><a class="nav-link active" data-toggle="tab" role="tab" href="#icmp" active>]] print(i18n("icmp")) print[[</a></li>
    <li class="nav-item"><a class="nav-link" data-toggle="tab" role="tab" href="#icmpv6">]] print(i18n("icmp")) print[[V6</a></li>
  </ul>
  <div class="tab-content">
    <div id="icmp" class="tab-pane in active">
      <br>
       <table id="icmp_table_4" class="table table-bordered table-striped tablesorter">
         <thead><tr><th>]] print(i18n("icmp_page.icmp_message")) print [[</th><th>]] print(i18n("icmp_page.icmp_type")) print [[</th><th>]] print(i18n("icmp_page.icmp_code")) print [[</th><th style='text-align:right;'>]] print(i18n("packets")) print[[</th></tr></thead>
         <tbody id="iface_details_icmp_tbody_4">
         </tbody>
       </table>
    </div>
    <div id="icmpv6" class="tab-pane">
      <br>
       <table id="icmp_table_6" class="table table-bordered table-striped tablesorter">
         <thead><tr><th>]] print(i18n("icmp_page.icmp_message")) print [[</th><th>]] print(i18n("icmp_page.icmp_type")) print [[</th><th>]] print(i18n("icmp_page.icmp_code")) print [[</th><th style='text-align:right;'>]] print(i18n("packets")) print[[</th></tr></thead>
         <tbody id="iface_details_icmp_tbody_6">
         </tbody>
       </table>
    </div>

<script>
function update_icmp_table(ip_version) {
  var icmp_table_id = '#icmp_table_' + ip_version;
  var icmp_table_body_id = '#iface_details_icmp_tbody_' + ip_version;

  $.ajax({
    type: 'GET',
    url: ']]
  print(ntop.getHttpPrefix())
  print [[/lua/get_icmp_data.lua',
    data: { ifid: "]] print(ifId.."")  print [[", version: ip_version },
    success: function(content) {
      if(content) {
         $(icmp_table_body_id).html(content);
         $(icmp_table_id).trigger("update");
      }
    }
  });
}

function update_icmp_tables() {
  update_icmp_table(4);
  update_icmp_table(6);
}

update_icmp_tables();
setInterval(update_icmp_tables, 5000);
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
      if(content) {
         $('#iface_details_arp_tbody').html(content);
         $('#arp_table').trigger("update");
      }
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
      l4proto = _GET["l4proto"],
   }
   url = url.."&page=historical"

   local top_enabled = top_talkers_utils.areTopEnabled(ifid)

   drawGraphs(ifstats.id, schema, tags, _GET["zoom"], url, selected_epoch, {
      top_protocols = "top:iface:ndpi",
      top_categories = "top:iface:ndpi_categories",
      top_profiles = "top:profile:traffic",
      top_senders = ternary(top_enabled, "top:local_senders", nil),
      top_receivers = ternary(top_enabled, "top:local_receivers", nil),
      l4_protocols = "iface:l4protos",
      show_historical = not ifstats.isViewed,
      timeseries = get_default_timeseries()
   })
elseif(page == "trafficprofiles") then
   print("<table class=\"table table-striped table-bordered\">\n")
   print("<tr><th width=15%><a href=\""..ntop.getHttpPrefix().."/lua/pro/admin/edit_profiles.lua\">" .. i18n("traffic_profiles.profile_name") .. "</A></th><th width=5%>" .. i18n("chart") .. "</th><th>" .. i18n("traffic") .. "</th></tr>\n")
   for pname,pbytes in pairs(ifstats.profiles) do
     local trimmed = trimSpace(pname)
     local statschart_icon = ''

     if areInterfaceTimeseriesEnabled(ifid) then
	 statschart_icon = '<A HREF=\"'..ntop.getHttpPrefix()..'/lua/profile_details.lua?profile='..pname..'\"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
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
   print [[/lua/rest/get/interface/data.lua',
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

elseif(page == "traffic_recording" and has_traffic_recording_page) then
   if not dismiss_recording_providers_reminder then
      print('<div id="traffic-recording-providers-detected" class="alert alert-info alert-dismissable"><button type="button" class="close" data-dismiss="alert" aria-label="close">&times;</button>'..i18n('traffic_recording.msg_external_providers_detected', {url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=config"})..'</div>')

      print [[
  <script>
    $('#traffic-recording-providers-detected').on('close.bs.alert', function () {
         var dismiss_notice = $.ajax({
          type: 'POST',
          url: ']]
   print (ntop.getHttpPrefix())
   print [[/lua/traffic_recording_config.lua',
          data: { ifid: ]] print(tostring(ifstats.id)) print[[,
                  dismiss_external_providers_reminder: true,
                  csrf: "]] print(ntop.getRandomCSRFValue()) print[["},
          success: function()  {},
          complete: function() {},
        });

    });
  </script>
]]
   end

   local tab = _GET["tab"] or "config"
   local recording_enabled = recording_utils.isEnabled(ifstats.id)
   -- config tab is only shown when the recording service is managed by ntopng
   -- otherwise it is assumed that the user is managing the service manually with n2disk
   local config_enabled  = (recording_utils.getCurrentTrafficRecordingProvider(ifstats.id) == "ntopng")

   if tab == "config" and not config_enabled then
      if recording_enabled then tab = "status" else tab = "" end
   end
   if (tab == "status" or tab == "jobs") and not recording_enabled then
      if config_enabled then tab = "config" else tab = "" end
   end

   if(_SERVER["REQUEST_METHOD"] == "POST") and (tab == "config") then
      recording_enabled = not isEmptyString(_POST["record_traffic"])
   end

   print('<ul id="traffic-recording-nav" class="nav nav-tabs" role="tablist">')

   if config_enabled then
      print('<li class="nav-item '.. ternary(tab == "config", "active", "") ..'"><a class="nav-link '.. ternary(tab == "config", "active", "") ..'" href="?ifid='.. ifstats.id
	       ..'&page=traffic_recording"><i class="fas fa-cog"></i> '.. i18n("traffic_recording.settings") ..'</a></li>')
   end

   if recording_enabled then
      print('<li class="nav-item '.. ternary(tab == "status", "active", "") ..'"><a class="nav-link '.. ternary(tab == "status", "active", "") ..'" href="?ifid='.. ifstats.id
	 ..'&page=traffic_recording&tab=status">'.. i18n("status") ..'</a></li>')

      if ntop.isEnterprise() then
	 print('<li class="nav-item '.. ternary(tab == "jobs", "active", "") ..'"><a class="nav-link '.. ternary(tab == "jobs", "active", "") ..'" href="?ifid='.. ifstats.id
	    ..'&page=traffic_recording&tab=jobs">'.. i18n("traffic_recording.jobs") ..'</a></li>')
      end
   end

   print('</ul>')
   print('<div class="tab-content">')

   if recording_enabled and tab == "status" then
      dofile(dirs.installdir .. "/scripts/lua/inc/traffic_recording_status.lua")
   elseif recording_enabled and ntop.isEnterprise() and tab == "jobs" then
      dofile(dirs.installdir .. "/scripts/lua/inc/traffic_recording_jobs.lua")
   elseif config_enabled and tab == "config" then -- config, default
      dofile(dirs.installdir .. "/scripts/lua/inc/traffic_recording_config.lua")
   end

   print('</div></div>')
elseif(page == "alerts") then

   printAlertTables("interface", ifname_clean,
      "if_stats.lua", {ifid=ifid}, if_name, "interface",
      {enable_label = i18n("show_alerts.trigger_iface_alert_descr", {iface = short_name})})

elseif(page == "config") then
   if(not isAdministrator()) then
      return
   end

   local messages = {}

   -- Flow dump check
   local interface_flow_dump = true
   if(prefs.is_dump_flows_enabled and ifstats.isView == false) then
      interface_flow_dump = (ntop.getPref("ntopng.prefs.ifid_"..ifId..".is_flow_dump_disabled") ~= "1")

      if _SERVER["REQUEST_METHOD"] == "POST" then
         local new_value = (_POST["interface_flow_dump"] == "1")

         if new_value ~= interface_flow_dump then
            -- Value changed
            interface_flow_dump = new_value
            ntop.setPref("ntopng.prefs.ifid_"..ifId..".is_flow_dump_disabled", ternary(interface_flow_dump, "0", "1"))

            messages[#messages + 1] = {
             type = "warning",
             text = i18n("prefs.restart_needed", {product=info.product}),
           }
         end
      end
   end

   if not table.empty(messages) then
      printMessageBanners(messages)
      print("<br>")
   end

   print[[
   <form id="iface_config" lass="form-inline" method="post">
   <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   <table id="iface_config_table" class="table table-bordered table-striped">]]

   if ((not is_pcap_dump) and
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
   end

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

   if not have_nedge then
     -- Scaling factor
     if interface.isPacketInterface() and not have_nedge then
	local label = ntop.getCache("ntopng.prefs.iface_"..tostring(ifid)..".scaling_factor")
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

   local serialize_by_mac
   local serialize_by_mac_key = string.format("ntopng.prefs.ifid_%u.serialize_local_broadcast_hosts_as_macs", ifId)

   if(_POST["lbd_hosts_as_macs"] ~= nil) then
      serialize_by_mac = _POST["lbd_hosts_as_macs"]

      if ntop.getPref(serialize_by_mac_key) ~= serialize_by_mac then
         ntop.setPref(serialize_by_mac_key, serialize_by_mac)
         interface.updateLbdIdentifier()
      end
   else
      serialize_by_mac = ntop.getPref(serialize_by_mac_key)
   end

   -- LBD identifier
     print[[
	<tr>
	   <th width="30%">]] print(i18n("prefs.toggle_host_tskey_title")) print[[ <i class="fas fa-info-circle" title="]] print(i18n("prefs.toggle_host_tskey_description")) print[["></i></th>
	   <td>]]
      inline_select_form("lbd_hosts_as_macs", {i18n("ip_address"), i18n("mac_address")}, {"0", "1"}, serialize_by_mac)
	print[[
	   </td>
	</tr>]]

   -- Hidden from top
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
         <div class="custom-control custom-switch">
            <input class="custom-control-input" id="interface_rrd_creation" name="interface_rrd_creation" type="checkbox" value="1" ]] print(interface_rrd_creation_checked) print[[>
            <label class="custom-control-label" for="interface_rrd_creation"></label>
         </div>
            </td>
      </tr>

      <script type="text/javascript">
        $("#interface_rrd_creation").change(function(){
          var self = this;
          $("#iface_config_table tr.rrd_creation").toggle(self.checked); 
        }).change();
     </script>
]]

   -- Skip timeseries for hosts with unidirectional traffic
   local interface_one_way_hosts_rrd_creation = true
   local interface_one_way_hosts_rrd_creation_checked = "checked"

   if _SERVER["REQUEST_METHOD"] == "POST" then
      if _POST["interface_one_way_hosts_rrd_creation"] ~= "1" then
	 interface_one_way_hosts_rrd_creation = false
	 interface_one_way_hosts_rrd_creation_checked = ""
      end

      ntop.setPref("ntopng.prefs.ifid_"..ifId..".interface_one_way_hosts_rrd_creation", tostring(interface_one_way_hosts_rrd_creation))
   else
      interface_one_way_hosts_rrd_creation = ntop.getPref("ntopng.prefs.ifid_"..ifId..".interface_one_way_hosts_rrd_creation")

      if interface_one_way_hosts_rrd_creation == "false" then
	 interface_one_way_hosts_rrd_creation = false
	 interface_one_way_hosts_rrd_creation_checked = ""
      end
   end

   print [[<tr class="rrd_creation" ]] if not interface_rrd_creation then print("style='display:none;'") end print[[>
	 <th>]] print(i18n("if_stats_config.interface_one_way_hosts_rrd_creation")) print[[</th>
    <td>
    <div class="custom-control custom-switch">
	    <input class="custom-control-input"  id="check-interface_one_way_hosts_rrd_creation" name="interface_one_way_hosts_rrd_creation" type="checkbox" value="1" ]] print(interface_one_way_hosts_rrd_creation_checked) print[[>
       <label class="custom-control-label" for="check-interface_one_way_hosts_rrd_creation"></label>
       </div>
       </td>
      </tr>]]

   -- per-interface Top-Talkers generation
   local interface_top_talkers_creation = true
   local interface_top_talkers_creation_checked = "checked"

   if _SERVER["REQUEST_METHOD"] == "POST" then
      if _POST["interface_top_talkers_creation"] ~= "1" then
	 interface_top_talkers_creation = false
	 interface_top_talkers_creation_checked = ""
	 top_talkers_utils.disableTop(ifId)
      else
	 top_talkers_utils.enableTop(ifId)
      end
   else
      if not top_talkers_utils.areTopEnabled(ifId) then
	 interface_top_talkers_creation_checked = ""
      end
   end

   print [[<tr>
         <th>]] print(i18n("if_stats_config.interface_top_talkers_creation")) print[[</th>
         <td>
            <div class="custom-control custom-switch">
               <input class="custom-control-input" id="check-interface_top_talkers_creation" name="interface_top_talkers_creation" type="checkbox" value="1" ]] print(interface_top_talkers_creation_checked) print[[>
               <label class="custom-control-label" for="check-interface_top_talkers_creation"></label>
            </div>
            </td>
      </tr>]]

   -- Flow dump
   if(prefs.is_dump_flows_enabled and ifstats.isView == false) then
      local interface_flow_dump_checked = ternary(interface_flow_dump, "checked", "")

      print [[<tr>
         <th>]] print(i18n("if_stats_config.dump_flows_to_database")) print[[</th>
         <td>
            <div class="custom-control custom-switch">
               <input class="custom-control-input" id="check-interface_flow_dump" name="interface_flow_dump" type="checkbox" value="1" ]] print(interface_flow_dump_checked) print[[>
               <label class="custom-control-label" for="check-interface_flow_dump"></label>
            </div>
         </td>
      </tr>]]
   end

   -- Mirrored Traffic
   if not ntop.isnEdge() and interface.isPacketInterface() then
      local is_mirrored_traffic = false
      local is_mirrored_traffic_checked = ""
      local is_mirrored_traffic_pref = string.format("ntopng.prefs.ifid_%d.is_traffic_mirrored", ifId)

      if _SERVER["REQUEST_METHOD"] == "POST" then
	 if _POST["is_mirrored_traffic"] == "1" then
	    is_mirrored_traffic = true
	    is_mirrored_traffic_checked = "checked"
	 end

	 ntop.setPref(is_mirrored_traffic_pref,
		      ternary(is_mirrored_traffic == true, '1', '0'))
	 interface.updateTrafficMirrored()
      else
	 is_mirrored_traffic = ternary(ntop.getPref(is_mirrored_traffic_pref) == '1', true, false)

	 if is_mirrored_traffic then
	    is_mirrored_traffic_checked = "checked"
	 end
      end

      print [[<tr>
	 <th>]] print(i18n("if_stats_config.is_mirrored_traffic")) print[[</th>
    <td>
      <div class="custom-control custom-switch">
         <input class="custom-control-input" type="checkbox" id="check-is_mirrored_traffic" name="is_mirrored_traffic" value="1" ]] print(is_mirrored_traffic_checked) print[[>
         <label class="custom-control-label" for="check-is_mirrored_traffic"></label>
      </div>
	 </td>
      </tr>]]
   end

   -- Flows-Only Interface
   if not ntop.isnEdge() and not interface.isView() and not interface.isViewed() then
      local flows_only_interface = false
      local flows_only_interface_checked = ""
      local flows_only_interface_pref = string.format("ntopng.prefs.ifid_%d.flows_only_interface", ifId)

      if _SERVER["REQUEST_METHOD"] == "POST" then
	 if _POST["flows_only_interface"] == "1" then
	    flows_only_interface = true
	    flows_only_interface_checked = "checked"
	 end

	 ntop.setPref(flows_only_interface_pref,
		      ternary(flows_only_interface == true, '1', '0'))
	 interface.updateDiscardProbingTraffic()
      else
	 flows_only_interface = ternary(ntop.getPref(flows_only_interface_pref) == '1', true, false)

	 if flows_only_interface then
	    flows_only_interface_checked = "checked"
	 end
      end

      print [[<tr>
	 <th>]] print(i18n("if_stats_config.flows_only_interface")) print[[</th>
    <td>
      <div class="custom-control custom-switch">
         <input class="custom-control-input" id="check-flows_only_interface" type="checkbox" name="flows_only_interface" value="1" ]] print(flows_only_interface_checked) print[[>
         <label class="custom-control-label" for="check-flows_only_interface"></label>   
      </div>
         </td>
      </tr>]]
   end

   -- Discard Probing Traffic
   if not ntop.isnEdge() and not interface.isPacketInterface() then
      local discard_probing_traffic = false
      local discard_probing_traffic_checked = ""
      local discard_probing_traffic_pref = string.format("ntopng.prefs.ifid_%d.discard_probing_traffic", ifId)

      if _SERVER["REQUEST_METHOD"] == "POST" then
	 if _POST["discard_probing_traffic"] == "1" then
	    discard_probing_traffic = true
	    discard_probing_traffic_checked = "checked"
	 end

	 ntop.setPref(discard_probing_traffic_pref,
		      ternary(discard_probing_traffic == true, '1', '0'))
	 interface.updateDiscardProbingTraffic()
      else
	 discard_probing_traffic = ternary(ntop.getPref(discard_probing_traffic_pref) == '1', true, false)

	 if discard_probing_traffic then
	    discard_probing_traffic_checked = "checked"
	 end
      end

      print [[<tr>
	 <th>]] print(i18n("if_stats_config.discard_probing_traffic")) print[[</th>
    <td>
      <div class="custom-control custom-switch">
         <input class="custom-control-input" id="check-discard_probing_traffic" type="checkbox" name="discard_probing_traffic" value="1" ]] print(discard_probing_traffic_checked) print[[>
         <label class="custom-control-label" for="check-discard_probing_traffic"></label>
      </div>
         </td>
      </tr>]]
   end

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
    <div class="custom-control custom-switch">
      <input class="custom-control-input" id="check-interface_network_discovery" type="checkbox" name="interface_network_discovery" value="1" ]] print(interface_network_discovery_checked) print[[>
    <label class="custom-control-label" for="check-interface_network_discovery"></label>
      </div>
      </td>
      </tr>]]
   end

   if interface.isPacketInterface() and not ifstats.isDynamic then
      local cur_companion = companion_interface_utils.getCurrentCompanion(ifstats.id)
      local companions = companion_interface_utils.getAvailableCompanions()

      if table.len(companions) > 1 then
	 print [[
       <tr>
	 <th>]] print(i18n("if_stats_config.companion_interface")) print[[</th>
	 <td>
	   <select name="companion_interface" class="form-control" style="width:36em; display:inline;">]]

	 for _, companion in ipairs(companions) do
	    local companion_id = companion["ifid"]
	    local companion_name = companion["ifname"]
	    local label = companion_name
	    if companion_name ~= "None" then
	       label = getHumanReadableInterfaceName(companion_name)
	    end

	    print[[<option value="]] print(companion_id) print[[" ]] if cur_companion == companion_id then print('selected="selected"') end print[[">]] print(label) print[[</option>]]
	 end

	 print[[
	   </select>
	 </td>
       </tr>]]
      end
   end

   if has_traffic_recording_page then
      local cur_provider = recording_utils.getCurrentTrafficRecordingProvider(ifstats.id)
      local providers = recording_utils.getAvailableTrafficRecordingProviders()

      -- only 1 provider means there's only the default ntopng
      -- so no need to show this extra menu entry
      if table.len(providers) > 1 then
	 print [[
       <tr>
	 <th>]] print(i18n("traffic_recording.traffic_recording_provider")) print[[</th>
	 <td>
	   <select name="traffic_recording_provider" class="form-control" style="width:36em; display:inline;">]]

	 for _, provider in pairs(providers) do
	    local label = string.format("%s", provider["name"])
	    if provider["conf"] then
	       label = string.format("%s (%s)", provider["name"], provider["conf"])
	    end

	    if provider["name"] == "ntopng" and not interface.isPacketInterface() then
	       -- non-packet interfaces
	       label = "none"
	    end

	    print[[<option value="]] print(provider["name"]) print[[" ]] if cur_provider == provider["name"] then print('selected="selected"') end print[[">]] print(label) print[[</option>]]
	 end

	 print[[
	   </select>
	 </td>
       </tr>]]
      end
   end

   if not ifstats.isDynamic then
      local cur_mode = ntop.getCache(disaggregation_criterion_key)
      if isEmptyString(cur_mode) then
         cur_mode = "none"
      end

      local labels = {
	i18n("prefs.none"),
	i18n("prefs.vlan"),
	i18n("prefs.probe_ip_address"),
	i18n("prefs.flow_interface"),
	i18n("prefs.ingress_flow_interface"),
	i18n("prefs.ingress_vrf_id")
      }

      local values = {}
      if is_packet_interface then
        values = {
 	  "none",
	  "vlan"
        }
      else
        values = {
 	  "none",
	  "vlan",
	  "probe_ip",
	  "iface_idx",
	  "ingress_iface_idx",
	  "ingress_vrf_id"
        }
      end

      print [[
       <tr>
	 <th>]] print(i18n("prefs.dynamic_interfaces_creation_title")) print[[</th>
	 <td>
	   <select name="disaggregation_criterion" class="form-control" style="width:36em; display:inline;">]]

	 for k, value in ipairs(values) do
	    local label = labels[k]
	    print[[<option value="]] print(value) print[[" ]] if cur_mode == value then print('selected="selected"') end print[[">]] print(label) print[[</option>]]
	 end

	 print[[
	   </select>
	  ]] 
         print ("<br><br><small><p><b>"..i18n("notes").."</b><ul>"..
		"<li>"..i18n("prefs.dynamic_interfaces_creation_description").."</li>"..
		"<li>"..i18n("prefs.dynamic_interfaces_creation_note_0").."</li>"..
		"<li>"..i18n("prefs.dynamic_interfaces_creation_note_4").."</li>"..
		"<li>"..i18n("prefs.dynamic_interfaces_creation_note_1").."</li>")
         if not is_packet_interface then
            print("<li>"..i18n("prefs.dynamic_interfaces_creation_note_2").."</li>"..
		  "<li>"..i18n("prefs.dynamic_interfaces_creation_note_3").."</li>")
         end
         print [[
           </ul></small>
	 </td>
       </tr>]]

      -- Show dynamic traffic in the master interface
      local show_dyn_iface_traffic = false
      local show_dyn_iface_traffic_checked = ""
      local show_dyn_iface_traffic_pref = string.format("ntopng.prefs.ifid_%d.show_dynamic_interface_traffic", ifId)

      if _SERVER["REQUEST_METHOD"] == "POST" then
	 if _POST["show_dyn_iface_traffic"] == "1" then
	    show_dyn_iface_traffic = true
	    show_dyn_iface_traffic_checked = "checked"
	 end

	 ntop.setPref(show_dyn_iface_traffic_pref,
		      ternary(show_dyn_iface_traffic == true, '1', '0'))
	 interface.updateDynIfaceTrafficPolicy()
      else
	 show_dyn_iface_traffic = ternary(ntop.getPref(show_dyn_iface_traffic_pref) == '1', true, false)

	 if show_dyn_iface_traffic then
	    show_dyn_iface_traffic_checked = "checked"
	 end
      end

      print [[<tr>
	 <th>]] print(i18n("if_stats_config.show_dyn_iface_traffic")) print[[</th>
    <td>
         <div class="custom-control custom-switch">
           <input id="show_dyn_iface_traffic" class="custom-control-input" type="checkbox" name="show_dyn_iface_traffic" value="1" ]] print(show_dyn_iface_traffic_checked) print[[>
          <label class="custom-control-label" for="show_dyn_iface_traffic"></label>
         </div>
           <br><br><small><p><b>]] print(i18n("notes")) print [[</b><ul><li>]] print(i18n("if_stats_config.show_dyn_iface_traffic_note")) print [[</li></ul></p></small>
	 </td>
      </tr>]]

   end

      print[[
   </table>
   <button class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>
   </form>
   <script>
      aysHandleForm("#iface_config");
   </script>]]

elseif(page == "internals") then
   internals_utils.printInternals(ifid, true --[[ hash tables ]], true --[[ periodic activities ]], true --[[ user scripts]])
print [[
   </table>
]]


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
   <button id="snmp_bind_submit" class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
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
elseif(page == "sub_interfaces") then
   if(isAdministrator() and ntop.isEnterprise()) then
      dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/sub_interfaces.lua")
   end
elseif(page == "pools") then
    dofile(dirs.installdir .. "/scripts/lua/admin/host_pools.lua")
elseif(page == "dhcp") then
    dofile(dirs.installdir .. "/scripts/lua/admin/dhcp.lua")
elseif page == "traffic_report" then
   dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/traffic_report.lua")
end

print("<script>\n")
print("var last_pkts  = " .. ifstats.stats.packets .. ";\n")
print("var last_in_pkts  = " .. ifstats.eth.ingress.packets .. ";\n")
print("var last_out_pkts  = " .. ifstats.eth.egress.packets .. ";\n")
print("var last_drops = " .. ifstats.stats.drops .. ";\n")
print("var last_engaged_alerts = " .. ifstats.num_alerts_engaged .. ";\n")
print("var last_dropped_alerts = " .. ifstats.num_dropped_alerts .. ";\n")

if(ifstats.zmqRecvStats ~= nil) then
   print("var last_zmq_time = 0;\n")
   print("var last_zmq_flows = ".. ifstats.zmqRecvStats.flows .. ";\n")
   print("var last_zmq_events = ".. ifstats.zmqRecvStats.events .. ";\n")
   print("var last_zmq_counters = ".. ifstats.zmqRecvStats.counters .. ";\n")
   print("var last_zmq_msg_drops = ".. ifstats.zmqRecvStats.zmq_msg_drops .. ";\n")
   print("var last_zmq_msg_rcvd = ".. ifstats.zmqRecvStats.zmq_msg_rcvd .. ";\n")
   print("var last_zmq_avg_msg_flows = 1;\n")

   print("var last_probe_zmq_exported_flows = ".. (ifstats["zmq.num_flow_exports"] or 0) .. ";\n")
end

if ifstats.stats.discarded_probing_packets then
   print("var last_discarded_probing_pkts  = " .. ifstats.stats.discarded_probing_packets .. ";\n")
end

print [[

var resetInterfaceCounters = function(drops_only) {
  var action = "reset_all";
  if(drops_only) action = "reset_drops";
  $.ajax({ type: 'post',
    url: ']]
print (ntop.getHttpPrefix())
print [[/lua/reset_stats.lua',
    data: {ifid: ]] print(ifstats.id) print [[, resetstats_mode:  action, csrf: "]] print(ntop.getRandomCSRFValue()) print[["},
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
print [[/lua/rest/get/interface/data.lua',
	  data: { iffilter: "]] print(tostring(interface.name2id(ifstats.name))) print [[" },
	  success: function(rsp) {

	var v = bytesToVolume(rsp.bytes);
	$('#if_bytes').html(v);

   $('#if_in_bytes').html(bytesToVolume(rsp.bytes_download));
	$('#if_out_bytes').html(bytesToVolume(rsp.bytes_upload));
   $('#if_in_pkts').html(addCommas(rsp.packets_download) + " Pkts");
	$('#if_out_pkts').html(addCommas(rsp.packets_upload)  + " Pkts");
   $('#pkts_in_trend').html(get_trend(last_in_pkts, rsp.bytes_download));
   $('#pkts_out_trend').html(get_trend(last_out_pkts, rsp.bytes_upload));
   last_in_pkts = rsp.bytes_download;
   last_out_pkts = rsp.bytes_upload;

        if (typeof rsp.zmqRecvStats !== 'undefined') {
           var diff, time_diff, label;
           var now = (new Date()).getTime();

           if(last_zmq_time > 0) {
              time_diff = now - last_zmq_time;
              diff = rsp.zmqRecvStats.flows - last_zmq_flows;

              if(diff > 0) {
                 rate = ((diff * 1000)/time_diff).toFixed(1);
                 label = " [" + fflows(rate) + "] " + get_trend(1,0);
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
           $('#if_zmq_msg_rcvd').html(addCommas(rsp.zmqRecvStats.zmq_msg_rcvd)+" "+get_trend(rsp.zmqRecvStats.zmq_msg_rcvd, last_zmq_msg_rcvd));
           $('#if_zmq_avg_msg_flows').html(addCommas(formatValue(rsp.zmqRecvStats.zmq_avg_msg_flows)));
           $('#if_num_remote_zmq_flow_exports').html(addCommas(rsp["zmq.num_flow_exports"])+" "+get_trend(rsp["zmq.num_flow_exports"], last_probe_zmq_exported_flows));

           last_zmq_flows = rsp.zmqRecvStats.flows;
           last_zmq_events = rsp.zmqRecvStats.events;
           last_zmq_counters = rsp.zmqRecvStats.counters;
           last_zmq_msg_drops = rsp.zmqRecvStats.zmq_msg_drops;
           last_zmq_msg_rcvd = rsp.zmqRecvStats.zmq_msg_rcvd;
           last_zmq_avg_msg_flows = rsp.zmqRecvStats.zmq_avg_msg_flows;
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
          $('#nfq_queue_total').addClass("badge badge-danger");
        } else {
          $('#nfq_queue_total').removeClass("badge badge-danger");
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

if ifstats.stats.discarded_probing_packets then
      print[[
	$('#if_discarded_probing_bytes').html(bytesToVolume(rsp.discarded_probing_bytes));
	$('#if_discarded_probing_pkts').html(formatPackets(rsp.discarded_probing_packets));
        $('#if_discarded_probing_trend').html(get_trend(last_discarded_probing_pkts, rsp.discarded_probing_packets));
        last_discarded_probing_pkts = rsp.discarded_probing_packets;
]]
end

print [[
	var pctg = 0;
	var drops = "";
	var last_pkt_retransmissions = ]] print(tostring(ifstats.tcpPacketStats.retransmissions)) print [[;
	var last_pkt_ooo =  ]] print(tostring(ifstats.tcpPacketStats.out_of_order)) print [[;
	var last_pkt_lost = ]] print(tostring(ifstats.tcpPacketStats.lost)) print [[;

	$('#pkt_retransmissions').html(fint(rsp.tcpPacketStats.retransmissions)+" Pkts");  $('#pkt_retransmissions_trend').html(get_trend(last_pkt_retransmissions, rsp.tcpPacketStats.retransmissions));
	$('#pkt_ooo').html(fint(rsp.tcpPacketStats.out_of_order)+" Pkts");  $('#pkt_ooo_trend').html(get_trend(last_pkt_ooo, rsp.tcpPacketStats.out_of_order));
	$('#pkt_lost').html(fint(rsp.tcpPacketStats.lost)+" Pkts"); $('#pkt_lost_trend').html(get_trend(last_pkt_lost, rsp.tcpPacketStats.lost));
	last_pkt_retransmissions = rsp.tcpPacketStats.retransmissions;
	last_pkt_ooo = rsp.tcpPacketStats.out_of_order;
	last_pkt_lost = rsp.tcpPacketStats.lost;

	$('#pkts_trend').html(get_trend(last_pkts, rsp.packets));
	$('#drops_trend').html(get_trend(last_drops, rsp.drops));
	last_pkts = rsp.packets;
	last_drops = rsp.drops;

  $('#engaged_alerts_trend').html(get_trend(last_engaged_alerts, rsp.engaged_alerts));
  last_engaged_alerts = rsp.engaged_alerts;
  $('#dropped_alerts_trend').html(get_trend(last_dropped_alerts, rsp.dropped_alerts));
  last_dropped_alerts = rsp.dropped_alerts;

	if((rsp.packets + rsp.drops) > 0) {
          pctg = ((rsp.drops*100)/(rsp.packets+rsp.drops)).toFixed(2);
        }

	if(rsp.drops > 0) {
          drops = '<span class="badge badge-danger">';
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
            .addClass("badge badge-danger")
            .html(fint(rsp.flow_export_drops));
          if(rsp.flow_export_count > 0) {
            $('#exported_flows_drops_pct')
              .addClass("badge badge-danger")
              .html("[" + Math.round(rsp.flow_export_drops / (rsp.flow_export_count + rsp.flow_export_count) * 100 * 1000) / 1000 + "%]");
          } else {
            $('#exported_flows_drops_pct').addClass("badge badge-danger").html("[100%]");
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
	$("#icmp_table_4").tablesorter();
	$("#icmp_table_6").tablesorter();
	$("#arp_table").tablesorter();
	$("#if_stats_ndpi").tablesorter();
	$("#if_stats_ndpi_categories").tablesorter();
    }
);
</script>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
