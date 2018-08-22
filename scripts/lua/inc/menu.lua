--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"

print[[
<script>
   /* Some localization strings to pass from lua to javacript */
   var i18n = {
      "no_results_found": "]] print(i18n("no_results_found")) print[[",
      "change_number_of_rows": "]] print(i18n("change_number_of_rows")) print[[",
      "no_data_available": "]] print(i18n("no_data_available")) print[[",
      "showing_x_to_y_rows": "]] print(i18n("showing_x_to_y_rows", {x="{0}", y="{1}", tot="{2}"})) print[[",
   };

   var http_prefix = "]] print(ntop.getHttpPrefix()) print[[";
</script>]]

if ntop.isnEdge() then
   dofile(dirs.installdir .. "/pro/scripts/lua/nedge/inc/menu.lua")
   return
end

local template = require "template_utils"

prefs = ntop.getPrefs()
local iface_names = interface.getIfNames()

-- tprint(iface_names)

num_ifaces = 0
for k,v in pairs(iface_names) do
   num_ifaces = num_ifaces+1
end


print [[
      <div class="masthead">
        <ul class="nav nav-pills pull-right">
   ]]


interface.select(ifname)
local ifs = interface.getStats()
ifId = ifs.id

-- ##############################################

if active_page == "home" or active_page == "about" then
  print [[ <li class="dropdown active"> ]]
else
  print [[ <li class="dropdown"> ]]
end

print [[
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">
        <i class="fa fa-home fa-lg"></i> <b class="caret"></b>
      </a>
    <ul class="dropdown-menu">
      <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/about.lua"><i class="fa fa-question-circle"></i> ]] print(i18n("about.about_ntopng")) print[[</a></li>
      <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/runtime.lua"><i class="fa fa-hourglass-start"></i> ]] print(i18n("about.runtime_status")) print[[</a></li>
      <li><a href="http://blog.ntop.org/" target="_blank"><i class="fa fa-rss"></i> ]] print(i18n("about.ntop_blog")) print[[ <i class="fa fa-external-link"></i></a></li>
      <li><a href="https://t.me/ntop_community" target="_blank"><i class="fa fa-telegram"></i> ]] print(i18n("about.telegram")) print[[ <i class="fa fa-external-link"></i></a></li>
      <li><a href="https://github.com/ntop/ntopng/issues" target="_blank"><i class="fa fa-bug"></i> ]] print(i18n("about.report_issue")) print[[ <i class="fa fa-external-link"></i></a></li>
<li class="divider"></li><li><a href="https://www.ntop.org/guides/ntopng/" target="_blank"><i class="fa fa-book"></i> ]] print(i18n("about.readme_and_manual")) print[[ <i class="fa fa-external-link"></i></a></li>

<li><a href="https://www.ntop.org/guides/ntopng/api/" target="_blank"><i class="fa fa-book"></i> ]] print("Lua/C API") print[[ <i class="fa fa-external-link"></i></a></li>

</ul>
]]

-- ##############################################

if interface.isPcapDumpInterface() == false then
   if(active_page == "dashboard") then
  print [[ <li class="dropdown active"> ]]
else
  print [[ <li class="dropdown"> ]]
   end

   print [[
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">
        <i class="fa fa-dashboard fa-lg"></i> <b class="caret"></b>
      </a>

    <ul class="dropdown-menu">
<li><a href="]]

print(ntop.getHttpPrefix())
if ntop.isPro() then
   print("/lua/pro/dashboard.lua")
else
   print("/lua/index.lua")
end

print [["><i class="fa fa-dashboard"></i> ]] print(i18n("dashboard.traffic_dashboard")) print[[</a></li>]]

  if(interface.isDiscoverableInterface()) then
    print('<li><a href="'..ntop.getHttpPrefix()..'/lua/discover.lua"><i class="fa fa-lightbulb-o"></i> ') print(i18n("prefs.network_discovery")) print('</a></li>')
  end

if(ntop.isPro()) then
  print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/report.lua"><i class="fa fa-area-chart"></i> ') print(i18n("report.traffic_report")) print('</a></li>')
end

if ntop.isPro() and prefs.is_dump_flows_to_mysql_enabled then
  print('<li class="divider"></li>')
  print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/db_explorer.lua?ifid='..ifId..'"><i class="fa fa-history"></i> ') print(i18n("db_explorer.historical_data_explorer")) print('</a></li>')
end


print [[
    </ul>
   ]]
end


-- ##############################################

if not ifs.isView and ntop.getPrefs().are_alerts_enabled == true then

   local alert_cache = interface.getCachedNumAlerts() or {}
   local active = ""
   local style = ""
   local color = ""

   -- if alert_cache["num_alerts_engaged"] > 0 then
   -- color = 'style="color: #B94A48;"' -- bootstrap danger red
   -- end

   if alert_cache["num_alerts_engaged"] == 0 and alert_cache["alerts_stored"] == false then
      style = ' style="display: none;"'
   end

   if active_page == "alerts" then
      active = ' active'
   end

   -- local color = "#F0AD4E" -- bootstrap warning orange
   print [[
      <li class="dropdown]] print(active) print[[" id="alerts-id"]] print(style) print[[>
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">
	 <i class="fa fa-warning fa-lg "]] print(color) print[["></i> <b class="caret"></b>
      </a>
    <ul class="dropdown-menu">
      <li>
        <a  href="]]
   print(ntop.getHttpPrefix())
   print [[/lua/show_alerts.lua">
          <i class="fa fa-warning" id="alerts-menu-triangle"></i> ]] print(i18n("show_alerts.detected_alerts")) print[[
        </a>
      </li>
]]
   if ntop.isEnterprise() then
      print[[
      <li>
        <a href="]]
      print(ntop.getHttpPrefix())
      print[[/lua/pro/enterprise/alerts_dashboard.lua"><i class="fa fa-dashboard"></i> ]] print(i18n("alerts_dashboard.alerts_dashboard")) print[[
        </a>
     </li>
     <li class="divider"></li>
     <li><a href="]] print(ntop.getHttpPrefix())
      print[[/lua/pro/enterprise/flow_alerts_explorer.lua"><i class="fa fa-history"></i> ]] print(i18n("flow_alerts_explorer.label")) print[[
        </a>
     </li>
]]
   end

   print[[
    </ul>
  </li>
   ]]
end

-- ##############################################

_ifstats = interface.getStats()

if(_ifstats.iface_sprobe) then
   url = ntop.getHttpPrefix().."/lua/sflows_stats.lua"
else
   url = ntop.getHttpPrefix().."/lua/flows_stats.lua"
end

if(active_page == "flows") then
   print('<li class="active"><a href="'..url..'">') print(i18n("flows")) print('</a></li>')
else
   print('<li><a href="'..url..'">') print(i18n("flows")) print('</a></li>')
end

-- ##############################################

if active_page == "hosts" then
  print [[ <li class="dropdown active"> ]]
else
  print [[ <li class="dropdown"> ]]
end
print [[
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">
        ]] print(i18n("flows_page.hosts")) print[[ <b class="caret"></b>
      </a>
    <ul class="dropdown-menu">
      <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/hosts_stats.lua">]] print(i18n("flows_page.hosts")) print[[</a></li>
      ]]

if ifs["has_macs"] == true then
   print('<li><a href="'..ntop.getHttpPrefix()..'/lua/macs_stats.lua?devices_mode=source_macs_only">') print(i18n("layer_2")) print('</a></li>')
end

print('<li><a href="'..ntop.getHttpPrefix()..'/lua/network_stats.lua">') print(i18n("networks")) print('</a></li>')

if not _ifstats.isView then
   print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pool_stats.lua">') print(i18n("host_pools.host_pools")) print('</a></li>')
end

  if(ntop.hasGeoIP()) then
     print('<li><a href="'..ntop.getHttpPrefix()..'/lua/as_stats.lua">') print(i18n("prefs.toggle_asn_rrds_title")) print('</a></li>')
     print('<li><a href="'..ntop.getHttpPrefix()..'/lua/country_stats.lua">') print(i18n("countries")) print('</a></li>')
  end
  print('<li><a href="'..ntop.getHttpPrefix()..'/lua/os_stats.lua">') print(i18n("operating_systems")) print('</a></li>')

  if(ntop.hasVLANs()) then
     print('<li><a href="'..ntop.getHttpPrefix()..'/lua/vlan_stats.lua">') print(i18n("vlan_stats.vlans")) print('</a></li>')
  end

  if(_ifstats.iface_sprobe) then
   print('<li><a href="'..ntop.getHttpPrefix()..'/lua/processes_stats.lua">') print(i18n("sprobe_page.processes")) print('</a></li>')
end

print('<li class="divider"></li>')
print('<li class="dropdown-header">') print(i18n("local_traffic")) print('</li>')

print('<li><a href="'..ntop.getHttpPrefix()..'/lua/local_hosts_stats.lua"><i class="fa fa-binoculars" aria-hidden="true"></i> ') print(i18n("local_hosts_stats.looking_glass")) print('</a></li>')
print('<li><a href="'..ntop.getHttpPrefix()..'/lua/http_servers_stats.lua">') print(i18n("http_servers_stats.http_servers")) print('</a></li>')
print('<li><a href="'..ntop.getHttpPrefix()..'/lua/top_hosts.lua"><i class="fa fa-trophy"></i> ') print(i18n("processes_stats.top_hosts")) print('</a></li>')
print('<li class="divider"></li>')

if(_ifstats.iface_sprobe) then
   print('<li><a href="'..ntop.getHttpPrefix()..'/lua/sprobe.lua"><i class="fa fa-flag"></i> ') print(i18n("sprobe_page.system_interactions")) print('</a></li>\n')
end


if(not(isLoopback(ifname))) then
   print [[
	    <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/hosts_geomap.lua"><i class="fa fa-map-marker"></i> ]] print(i18n("geo_map.geo_map")) print[[</a></li>]]

   print[[<li><a href="]] print(ntop.getHttpPrefix())
   print [[/lua/hosts_treemap.lua"><i class="fa fa-sitemap"></i> ]] print(i18n("tree_map.hosts_treemap")) print[[</a></li>]]
end

print [[
      <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/hosts_matrix.lua"><i class="fa fa-th-large"></i> ]] print(i18n("local_flow_matrix.local_flow_matrix")) print[[</a></li>
   ]]

print("</ul> </li>")

-- Devices
info = ntop.getInfo()

local is_bridge_interface = isBridgeInterface(_ifstats)

-- Interfaces
if(num_ifaces > 0) then
if active_page == "if_stats" then
  print [[ <li class="dropdown active"> ]]
else
  print [[ <li class="dropdown"> ]]
end

print [[
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">]] print(i18n("interfaces")) print[[ <b class="caret"></b>
      </a>
      <ul class="dropdown-menu">
]]

local views = {}
local drops = {}
local packetinterfaces = {}
local ifnames = {}
local ifdescr = {}
local ifHdescr = {}
local ifCustom = {}

for v,k in pairs(iface_names) do
   interface.select(k)
   _ifstats = interface.getStats()
   ifnames[_ifstats.id] = k
   ifdescr[_ifstats.id] = _ifstats.description
   --io.write("["..k.."/"..v.."][".._ifstats.id.."] "..ifnames[_ifstats.id].."=".._ifstats.id.."\n")
   if(_ifstats.isView == true) then views[k] = true end
   if(interface.isPacketInterface()) then packetinterfaces[k] = true end
   if(_ifstats.stats_since_reset.drops * 100 > _ifstats.stats_since_reset.packets) then
      drops[k] = true
   end
   ifHdescr[_ifstats.id] = getHumanReadableInterfaceName(_ifstats.description.."")
   ifCustom[_ifstats.id] = _ifstats.customIftype
end

-- First round: only physical interfaces
-- Second round: only virtual interfaces

for round = 1, 2 do

   for k,_ in pairsByValues(ifHdescr, asc) do
      local descr
      
      if((round == 1) and (ifCustom[k] ~= nil)) then
   	 -- do nothing
      elseif((round == 2) and (ifCustom[k] == nil)) then
      	 -- do nothing
      else
	 v = ifnames[k]
	 print("      <li>")

	 if(v == ifname) then
	    print("<a href=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..k.."\">")
	 else
	    print[[<form id="switch_interface_form_]] print(tostring(k)) print[[" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/if_stats.lua?ifid=]] print(tostring(k)) print[[">]]
	    print[[<input name="switch_interface" type="hidden" value="1" />]]
	    print[[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />]]
	    print[[</form>]]
	    print[[<a href="javascript:void(0);" onclick="$('#switch_interface_form_]] print(tostring(k)) print[[').submit();">]]
	 end

	 if(v == ifname) then print("<i class=\"fa fa-check\"></i> ") end
	 if(isPausedInterface(v)) then  print('<i class="fa fa-pause"></i> ') end

	 descr = getHumanReadableInterfaceName(v.."")

	 if(string.contains(descr, "{")) then -- Windows
	    descr = ifdescr[k]      
	 else
	    if(v ~= ifdescr[k]) then
	       descr = descr .. " (".. ifdescr[k] ..")"
	    end
	 end

	 print(descr)
	 if(views[v] == true) then
	    print(' <i class="fa fa-eye" aria-hidden="true"></i> ')
	 end

	 if(drops[v] == true) then
	    print('&nbsp;<span><i class="fa fa-tint" aria-hidden="true"></i></span>')
	 end

	 print("</a>")
	 print("</li>\n")
      end
   end
end

print [[

      </ul>
    </li>
]]
end


if(ntop.isEnterprise()) then
   if active_page == "devices_stats" then
     print [[ <li class="dropdown active"> ]]
   else
     print [[ <li class="dropdown"> ]]
   end

   print [[
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">]] print(i18n("users.devices")) print[[ <b class="caret"></b>
      </a>
      <ul class="dropdown-menu">
   ]]

   if(info["version.enterprise_edition"] == true) then
      if ifs["type"] == "zmq" then
         print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/flowdevices_stats.lua">') print(i18n("flows_page.flow_exporters")) print('</a></li>')
         print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/flowdevices_stats.lua?sflow_filter=All">') print(i18n("flows_page.sflow_devices")) print('</a></li>')
      end
      print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/snmpdevices_stats.lua">') print(i18n("prefs.snmp")) print('</a></li>')
   end

   print("</ul> </li>")

end



-- Admin
if active_page == "admin" then
  print [[ <li class="dropdown active"> ]]
else
  print [[ <li class="dropdown"> ]]
end

print [[
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">
        <i class="fa fa-cog fa-lg"></i> <b class="caret"></b>
      </a>
    <ul class="dropdown-menu">]]

user_group = ntop.getUserGroup()

if(user_group == "administrator") then
  print[[<li><a href="]] print(ntop.getHttpPrefix())
  print[[/lua/admin/users.lua"><i class="fa fa-user"></i> ]] print(i18n("manage_users.manage_users")) print[[</a></li>]]
else
  print [[<li><a href="#password_dialog"  data-toggle="modal"><i class="fa fa-user"></i> ]] print(i18n("login.change_password")) print[[</a></li>]]
end

if(user_group == "administrator") then
   print("<li><a href=\""..ntop.getHttpPrefix().."/lua/admin/prefs.lua\"><i class=\"fa fa-flask\"></i> ") print(i18n("prefs.preferences")) print("</a></li>\n")

   if is_bridge_interface and ntop.isEnterprise() then
      print[[<form id="go_show_bridge_wizard" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/if_stats.lua">]]
      print[[<input name="show_wizard" type="hidden" value="" />]]
      print[[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />]]
      print[[</form>]]
      print("<li><a href=\"javascript:void(0)\" onclick=\"$('#go_show_bridge_wizard').submit();\"><i class=\"fa fa-magic\"></i> "..i18n("bridge_wizard.bridge_wizard").."</a></li>\n")
   end

   if(ntop.isPro()) then
      print("<li><a href=\""..ntop.getHttpPrefix().."/lua/pro/admin/edit_profiles.lua\"><i class=\"fa fa-user-md\"></i> ") print(i18n("traffic_profiles.traffic_profiles")) print("</a></li>\n")
      if(false) then
	 print("<li><a href=\""..ntop.getHttpPrefix().."/lua/pro/admin/list_reports.lua\"><i class=\"fa fa-archive\"></i> Reports Archive</a></li>\n")
      end

      print("<li><a href=\""..ntop.getHttpPrefix().."/lua/admin/edit_ndpi_applications.lua\"><i class=\"fa fa-tags\"></i> ") print(i18n("protocols")) print("</a></li>\n")
   end

end


print [[
      <li class="divider"></li>]]

print [[
      <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/manage_data.lua"><i class="fa fa-share"></i> ]] print(i18n("manage_data.manage_data")) print[[</a></li>]]

if(user_group == "administrator") then
  print [[
      <li><a href="]]
  print(ntop.getHttpPrefix())
  print [[/lua/get_config.lua"><i class="fa fa-download"></i> ]] print(i18n("conf_backup.conf_backup")) print[[</a></li>]]

  print[[ <li><a href="https://www.ntop.org/guides/ntopng/web_gui/settings.html#restore-configuration" target="_blank"><i class="fa fa-upload"></i> ]] print(i18n("conf_backup.conf_restore")) print[[ <i class="fa fa-external-link"></i></a></li>]]
end

print[[
    </ul>
  </li>]]

if(_SESSION["user"] ~= nil and _SESSION["user"] ~= ntop.getNologinUser()) then
print [[
    <li class="dropdown">
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">
	 <i class="fa fa-power-off fa-lg"></i> <b class="caret"></b>
      </a>
    <ul class="dropdown-menu">]]

print[[<li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/logout.lua"><i class="fa fa-sign-out"></i> ]] print(i18n("login.logout_user_x", {user=_SESSION["user"]})) print [[</a></li>]]

   print[[
    </ul>
    </li>
   ]]
end


if(user_group ~= "administrator") then
   dofile(dirs.installdir .. "/scripts/lua/inc/password_dialog.lua")
end
print("<li>")
print(
  template.gen("typeahead_input.html", {
    typeahead={
      base_id     = "host_search",
      action      = "", -- see makeFindHostBeforeSubmitCallback
      json_key    = "ip",
      query_field = "host",
      query_url   = ntop.getHttpPrefix() .. "/lua/find_host.lua",
      query_title = i18n("search_host"),
      style       = "width:16em;",
      before_submit = [[makeFindHostBeforeSubmitCallback("]] .. ntop.getHttpPrefix() .. [[")]],
    }
  })
)
print("</li>")

print("</ul>\n<h3 class=\"muted\"><A href=\"http://www.ntop.org\">")

addLogoSvg()

print("</A></h3>\n</div>\n")

-- select the original interface back to prevent possible issues
interface.select(ifname)
