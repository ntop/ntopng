--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

page = _GET["page"]
if(page == nil) then page = "UserApps" end
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

user_key = _GET["user"]
host_key = _GET["host"]
application = _GET["application"]

if(user_key == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Missing user name</div>")
else
  if(host_key ~= nil) then
    name = ntop.getResolvedAddress(host_key)
    if (name == nil) then
      name = host_key
    end
  end
  print [[
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
      <ul class="nav navbar-nav">
	    <li><a href="#"><i class="fa fa-user fa-lg"></i> ]] print(user_key) if(host_key ~= nil) then print(' - <i class="fa fa-building fa-lg"></i> '..name) end print [[  </a></li>
   ]]


if(page == "UserApps") then active=' class="active"' else active = "" end
print('<li'..active..'><a href="?user='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=UserApps">Applications</a></li>\n')

if(page == "UserProtocols") then active=' class="active"' else active = "" end
print('<li'..active..'><a href="?user='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=UserProtocols">Protocols</a></li>\n')

if(page == "Flows") then active=' class="active"' else active = "" end
print('<li'..active..'><a href="?user='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows">Flow</a></li>\n')


print('</ul>\n\t</div>\n\t\t</nav>\n')


if(page == "UserApps") then
print [[
    <table class="table table-bordered table-striped">
      <tr><th class="text-center">
      <h4>Top Applications</h4>
        <td><div class="pie-chart" id="topApps"></div></td>
      
      </th>
    </tr>]]

 print [[
      </table>
<script type='text/javascript'>
window.onload=function() {
   var refresh = 3000 /* ms */;
		    do_pie("#topApps", ']]
print (ntop.getHttpPrefix())
print [[/lua/user_stats.lua', { user: "]] print(user_key) print [[", mode: "apps" ]] 
if (host_key ~= nil) then print(", host: \""..host_key.."\"") end
print [[
 }, "", refresh);
}
</script>
]]

elseif(page == "UserProtocols") then

print [[
  <br>
  <!-- Left Tab -->
  <div class="tabbable tabs-left">
    
    <ul class="nav nav-tabs">
      <li class="active"><a href="#l7" data-toggle="tab">L7 Protocols</a></li>
      <li><a href="#l4" data-toggle="tab">L4 Protocols</a></li>
    </ul>
    
      <!-- Tab content-->
      <div class="tab-content">

        <div class="tab-pane active" id="l7">
          <table class="table table-bordered table-striped">
            <tr>
              <th class="text-center">Top L7 Protocols</th>
              <td><div class="pie-chart" id="topL7"></div></td>
          </tr>
          </table>
        </div> <!-- Tab l7-->


        <div class="tab-pane" id="l4">
          <table class="table table-bordered table-striped">
            <tr>
              <th class="text-center">Top L4 Protocols</th>
              <td><div class="pie-chart" id="topL4"></div></td>
          </tr>
          </table>
        </div> <!-- Tab l4-->

      </div> <!-- End Tab content-->
    </div> <!-- End Left Tab -->

]]

 print [[
      </table>
<script type='text/javascript'>
window.onload=function() {
   var refresh = 3000 /* ms */;
		    do_pie("#topL7", ']]
print (ntop.getHttpPrefix())
print [[/lua/user_stats.lua', { user: "]] print(user_key) print [[", mode: "l7" ]] 
if (host_key ~= nil) then print(", host: \""..host_key.."\"") end
print [[
 }, "", refresh);
		    do_pie("#topL4", ']]
print (ntop.getHttpPrefix())
print [[/lua/user_stats.lua', { user: "]] print(user_key) print [[", mode: "l4" ]] 
if (host_key ~= nil) then print(", host: \""..host_key.."\"") end
print [[
 }, "", refresh);
}
</script>
]]

elseif(page == "Flows") then

stats = interface.getnDPIStats()
num_param = 0

print [[
      <div id="table-hosts"></div>
   <script>
   $("#table-hosts").datatable({
      url: "]]
print (ntop.getHttpPrefix())
print [[/lua/get_flows_data.lua]] 
if(application ~= nil) then
   print("?application="..application)
   num_param = num_param + 1
end

if(user_key ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
   print("user="..user_key)
   num_param = num_param + 1
end

if(host_key ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
  print("host="..host_key)
  num_param = num_param + 1
end

print [[",
         showPagination: true,
         buttons: [ '<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Applications<span class="caret"></span></button> <ul class="dropdown-menu" id="flow_dropdown">]]

print('<li><a href="'..ntop.getHttpPrefix()..'/lua/get_user_info.lua?user='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows">All Proto</a></li>')
for key, value in pairsByKeys(stats["ndpi"], asc) do
   class_active = ''
   if(key == application) then
      class_active = ' class="active"'
   end
   print('<li '..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/get_user_info.lua?user='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows&application=' .. key..'">'..key..'</a></li>')
end


print("</ul> </div>' ],\n")


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/sflows_stats_top.inc")

prefs = ntop.getPrefs()

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/sflows_stats_bottom.inc")




end -- If page



end



dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
