--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if ( (dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"

prefs = ntop.getPrefs()
names = interface.getIfNames()
num_ifaces = 0
for k,v in pairs(names) do num_ifaces = num_ifaces+1 end

print [[
      <div class="masthead">
        <ul class="nav nav-pills pull-right">
   ]]

interface.select(ifname)

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
      <li><a href="http://blog.ntop.org/" target="_blank"><i class="fa fa-globe"></i> ntop Blog <i class="fa fa-external-link"></i></a></li>
      <li><a href="https://github.com/ntop/ntopng/issues" target="_blank"><i class="fa fa-bug"></i> Report an Issue <i class="fa fa-external-link"></i></a></li>
      <li class="divider"></li>
      <li><a href="]]

print(ntop.getHttpPrefix())
if(ntop.isPro()) then
   print("/lua/pro/dashboard.lua")
else
   print("/lua/index.lua")
end

print [["><i class="fa fa-dashboard"></i> Dashboard</a></li>
      ]]

if(ntop.isPro()) then
	print('<li><a href="'..ntop.getHttpPrefix()..'/lua/pro/report.lua"><i class="fa fa-area-chart"></i> Report</a></li>')
end

print [[    </ul>
  </li>

   ]]

_ifstats = aggregateInterfaceStats(interface.getStats())

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

  print('<li><a href="'..ntop.getHttpPrefix()..'/lua/mac_stats.lua">MAC Addresses</a></li>')

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

print('<li><a href="'..ntop.getHttpPrefix()..'/lua/http_servers_stats.lua">HTTP Servers (Local)</a></li>')

print('<li class="divider"></li>')

print('<li><a href="'..ntop.getHttpPrefix()..'/lua/top_hosts.lua"><i class="fa fa-trophy"></i> Top Hosts (Local)</a></li>')

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

if(_ifstats["has_mesh_networks_traffic"]) then
   print [[ <li><a href="]] print(ntop.getHttpPrefix()) print [[/lua/mesh_antenna_stats.lua"><i class="fa fa-wifi"></i> Mesh Antenna Stats</a></li> ]]
end

print("</ul> </li>")


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

for v,k in pairs(interface.getIfNames()) do
   interface.select(k)
   _ifstats = interface.getStats()
   ifnames[_ifstats.id] = k
   --io.write(ifnames[_ifstats.id].."=".._ifstats.id.."\n")
   if(_ifstats.isView == true) then views[k] = true end
end

for k,v in pairsByKeys(ifnames, asc) do
   print("      <li>")   
   --io.write(k.."="..v.."\n")

   if(v == ifname) then
      print("<a href=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?if_name="..v.."\">")
   else
      print("<a href=\""..ntop.getHttpPrefix().."/lua/set_active_interface.lua?id="..k.."\">")
   end
   
   if(v == ifname) then print("<i class=\"fa fa-check\"></i> ") end
   if (isPausedInterface(v)) then  print('<i class="fa fa-pause"></i> ') end
   
   print(getHumanReadableInterfaceName(v..""))
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
  print(ntop.getHttpPrefix())
  print [[/lua/admin/change_user_password.lua"><i class="fa fa-user"></i> Change Password</a></li>
      ]]
end

if(user_group == "administrator") then
   print("<li><a href=\""..ntop.getHttpPrefix().."/lua/admin/prefs.lua\"><i class=\"fa fa-flask\"></i> Preferences</a></li>\n")

   if (ntop.isPro()) then
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
	 <i class="fa fa-user fa-lg"></i> <b class="caret"></b>
      </a>
    <ul class="dropdown-menu">
	 <li><a href="]]
print(ntop.getHttpPrefix())
print [[/lua/logout.lua"><i class="fa fa-power-off"></i> Logout ]]    print(_COOKIE["user"]) print [[</a></li>
    </ul>
    </li>
   ]]
end

if(ntop.getNumQueuedAlerts() > 0) then
print [[
<li>
<a  href="]]
print(ntop.getHttpPrefix())
print [[/lua/show_alerts.lua">
<i class="fa fa-warning fa-lg" style="color: #B94A48;"></i>
</a>
</li>
   ]]
end


dofile(dirs.installdir .. "/scripts/lua/inc/search_host_box.lua")

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

if(file_exists(dirs.installdir .. "/httpdocs/img/custom_logo.jpg")) then
   logo_path = ntop.getHttpPrefix().."/img/custom_logo.jpg"
else
   logo_path = ntop.getHttpPrefix().."/img/logo.png"
end

print("</ul>\n<h3 class=\"muted\"><A href=http://www.ntop.org><img src=\""..logo_path.."\"></A></h3>\n</div>\n")

