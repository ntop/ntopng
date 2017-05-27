--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
local template = require "template_utils"

prefs = ntop.getPrefs()
names = interface.getIfNames()
num_ifaces = 0
for k,v in pairs(names) do
   num_ifaces = num_ifaces+1
end

-- tprint(names)

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
print [[/lua/about.lua"><i class="fa fa-question-circle"></i> About ntopng</a></li>
      <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/runtime.lua"><i class="fa fa-hourglass-start"></i> Runtime Status</a></li>
      <li><a href="https://github.com/ntop/ntopng/tree/dev/doc" target="_blank"><i class="fa fa-book"></i> Readme and Manual <i class="fa fa-external-link"></i></a></li>
      <li><a href="http://blog.ntop.org/" target="_blank"><i class="fa fa-rss"></i> ntop Blog <i class="fa fa-external-link"></i></a></li>
      <li><a href="https://github.com/ntop/ntopng/issues" target="_blank"><i class="fa fa-bug"></i> Report an Issue <i class="fa fa-external-link"></i></a></li>
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

print [["><i class="fa fa-dashboard"></i> Traffic Dashboard</a></li>]]

if(ntop.isPro()) then
	print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/report.lua"><i class="fa fa-area-chart"></i> Traffic Report</a></li>')
end

if ntop.isPro() and prefs.is_dump_flows_to_mysql_enabled then
  print('<li class="divider"></li>')
  print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/db_explorer.lua?ifid='..ifId..'"><i class="fa fa-history"></i> Historical Data Explorer</a></li>')
end


print [[
    </ul>
   ]]
end


-- ##############################################

interface.select(ifname)
if ntop.getPrefs().are_alerts_enabled == true then

   local alert_cache = interface.getCachedNumAlerts()
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
          <i class="fa fa-warning id="alerts-menu-triangle"></i> Detected Alerts
        </a>
      </li>
]]
   if ntop.isEnterprise() then
      print[[
      <li>
        <a href="]]
      print(ntop.getHttpPrefix())
      print[[/lua/pro/enterprise/alerts_dashboard.lua"><i class="fa fa-dashboard"></i> Alerts Dashboard
        </a>
     </li>
     <li class="divider"></li>
     <li><a href="]] print(ntop.getHttpPrefix())
      print[[/lua/pro/enterprise/flow_alerts_explorer.lua"><i class="fa fa-history"></i> Historical Alerts Explorer
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
   print('<li class="active"><a href="'..url..'">Flows</a></li>')
else
   print('<li><a href="'..url..'">Flows</a></li>')
end

-- ##############################################

if active_page == "hosts" then
  print [[ <li class="dropdown active"> ]]
else
  print [[ <li class="dropdown"> ]]
end
print [[
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">
        Hosts <b class="caret"></b>
      </a>
    <ul class="dropdown-menu">
      <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/hosts_stats.lua">Hosts</a></li>
      ]]

   print('<li><a href="'..ntop.getHttpPrefix()..'/lua/network_stats.lua">Networks</a></li>')
if not _ifstats.isView then
   print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pool_stats.lua">Host Pools</a></li>')
end

  if(ntop.hasGeoIP()) then
     print('<li><a href="'..ntop.getHttpPrefix()..'/lua/as_stats.lua">Autonomous Systems</a></li>')
     print('<li><a href="'..ntop.getHttpPrefix()..'/lua/country_stats.lua">Countries</a></li>')
  end
  print('<li><a href="'..ntop.getHttpPrefix()..'/lua/os_stats.lua">Operating Systems</a></li>')

  if(ntop.hasVLANs()) then
     print('<li><a href="'..ntop.getHttpPrefix()..'/lua/vlan_stats.lua">VLANs</a></li>')
  end

  if(_ifstats.iface_sprobe) then
   print('<li><a href="'..ntop.getHttpPrefix()..'/lua/processes_stats.lua">Processes</a></li>')
end

print('<li class="divider"></li>')
print('<li class="dropdown-header">Local Traffic</li>')
print('<li><a href="'..ntop.getHttpPrefix()..'/lua/local_hosts_stats.lua"><i class="fa fa-binoculars" aria-hidden="true"></i> Looking Glass</a></li>')
print('<li><a href="'..ntop.getHttpPrefix()..'/lua/http_servers_stats.lua">HTTP Servers</a></li>')
print('<li><a href="'..ntop.getHttpPrefix()..'/lua/top_hosts.lua"><i class="fa fa-trophy"></i> Top Hosts</a></li>')

print('<li class="divider"></li>')

if(_ifstats.iface_sprobe) then
   print('<li><a href="'..ntop.getHttpPrefix()..'/lua/sprobe.lua"><i class="fa fa-flag"></i> System Interactions</a></li>\n')
end


if(not(isLoopback(ifname))) then
   print [[
	    <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/hosts_geomap.lua"><i class="fa fa-map-marker"></i> Geo Map</a></li>
	    <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/hosts_treemap.lua"><i class="fa fa-sitemap"></i> Tree Map</a></li>
      ]]
end

print [[
      <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/hosts_matrix.lua"><i class="fa fa-th-large"></i> Local Flow Matrix</a></li>
   ]]

print("</ul> </li>")

-- Devices
info = ntop.getInfo()

if((ifs["has_macs"] == true) or ntop.isPro()) then
if active_page == "devices_stats" then
  print [[ <li class="dropdown active"> ]]
else
  print [[ <li class="dropdown"> ]]
end

print [[
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">Devices <b class="caret"></b>
      </a>
      <ul class="dropdown-menu">
]]

if ifs["has_macs"] == true then
   print('<li><a href="'..ntop.getHttpPrefix()..'/lua/mac_stats.lua">Layer 2</a></li>')
   if(info["version.enterprise_edition"] == true) then
      print('<li class="divider"></li>')
   end
end

if(info["version.enterprise_edition"] == true) then
   if ifs["type"] == "zmq" then
      print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/flowdevices_stats.lua">Flow Exporters</a></li>')
      print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/flowdevices_stats.lua?sflow_filter=All">sFlow Devices</a></li>')
   end
   print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/snmpdevices_stats.lua">SNMP</a></li>')
end

print("</ul> </li>")
end

local is_bridge_interface = isBridgeInterface(_ifstats)

-- Interfaces
if(num_ifaces > 0) then
if active_page == "if_stats" then
  print [[ <li class="dropdown active"> ]]
else
  print [[ <li class="dropdown"> ]]
end

print [[
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">Interfaces <b class="caret"></b>
      </a>
      <ul class="dropdown-menu">
]]

views = {}
ifnames = {}
ifdescr = {}

for v,k in pairs(interface.getIfNames()) do
   interface.select(k)
   _ifstats = interface.getStats()
   ifnames[_ifstats.id] = k
   ifdescr[_ifstats.id] = _ifstats.description
   --io.write("["..k.."/"..v.."][".._ifstats.id.."] "..ifnames[_ifstats.id].."=".._ifstats.id.."\n")
   if(_ifstats.isView == true) then views[k] = true end
end

for k,v in pairsByKeys(ifnames, asc) do
   local descr
   
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
      elseif(v ~= descr) then
	 descr = descr .. " (".. v ..")"
      end
   end
   
   print(descr)
   if(views[v] == true) then print(' <i class="fa fa-eye"></i> ') end
   print("</a>")
   print("</li>\n")
end


print [[

      </ul>
    </li>
]]
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
    <ul class="dropdown-menu">
      <li><a href="]]

user_group = ntop.getUserGroup()

if(user_group == "administrator") then
  print(ntop.getHttpPrefix())
  print [[/lua/admin/users.lua"><i class="fa fa-user"></i> Manage Users</a></li>
      ]]
else
  print [[#password_dialog"  data-toggle="modal"><i class="fa fa-user"></i> Change Password</a></li>
      ]]
end

if(user_group == "administrator") then
   print("<li><a href=\""..ntop.getHttpPrefix().."/lua/admin/prefs.lua\"><i class=\"fa fa-flask\"></i> Preferences</a></li>\n")

   if is_bridge_interface and ntop.isEnterprise() then
      print[[<form id="go_show_bridge_wizard" method="post" action="]] print(ntop.getHttpPrefix()) print[[/lua/if_stats.lua">]]
      print[[<input name="show_wizard" type="hidden" value="" />]]
      print[[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />]]
      print[[</form>]]
      print("<li><a href=\"javascript:void(0)\" onclick=\"$('#go_show_bridge_wizard').submit();\"><i class=\"fa fa-magic\"></i> "..i18n("bridge_wizard.bridge_wizard").."</a></li>\n")
   end

   if(ntop.isPro()) then
      print("<li><a href=\""..ntop.getHttpPrefix().."/lua/pro/admin/edit_profiles.lua\"><i class=\"fa fa-user-md\"></i> Traffic Profiles</a></li>\n")
      if(false) then
	 print("<li><a href=\""..ntop.getHttpPrefix().."/lua/pro/admin/list_reports.lua\"><i class=\"fa fa-archive\"></i> Reports Archive</a></li>\n")
      end
   end

end

print [[
      <li class="divider"></li>
      <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/export_data.lua"><i class="fa fa-share"></i> Export Data</a></li>
    </ul>
    </li>
   ]]

if(_COOKIE["user"] ~= nil and _COOKIE["user"] ~= ntop.getNologinUser()) then
print [[
    <li class="dropdown">
      <a class="dropdown-toggle" data-toggle="dropdown" href="#">
	 <i class="fa fa-power-off fa-lg"></i> <b class="caret"></b>
      </a>
    <ul class="dropdown-menu">
	 <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/logout.lua"><i class="fa fa-sign-out"></i> Logout ]]    print(_COOKIE["user"]) print [[</a></li>
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
      action      = "/lua/host_details.lua",
      json_key    = "ip",
      query_field = "host",
      query_url   = ntop.getHttpPrefix() .. "/lua/find_host.lua",
      query_title = "Search Host",
      style       = "width:16em;",
    }
  })
)
print("</li>")

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

print("</ul>\n<h3 class=\"muted\"><A href=\"http://www.ntop.org\">")

if(false) then
if(file_exists(dirs.installdir .. "/httpdocs/img/custom_logo.jpg")) then
   logo_path = ntop.getHttpPrefix().."/img/custom_logo.jpg"
else
   logo_path = ntop.getHttpPrefix().."/img/logo.png"
end

print("<img src=\""..logo_path.."\">")
end

addLogoSvg()

print("</A></h3>\n</div>\n")

-- select the original interface back to prevent possible issues
interface.select(ifname)
