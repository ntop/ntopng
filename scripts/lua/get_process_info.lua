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
if(page == nil) then page = "Protocols" end
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

pid_key = _GET["pid"]
name_key = _GET["pid_name"]
host_key = _GET["host"]
application = _GET["application"]

general_process = 0

interface.select(ifname)

if((pid_key == nil) and (name_key == nil))then
   print("<div class=\"alert alert-danger\"><img src=/img/warning.png> Missing pid name</div>")
else
  if ((name_key ~= nil) and (pid_key == nil) and (host_key == nil)) then
    general_process = 1
  end
  -- Prepare displayed value
  if (pid_key ~= nil) then
   flows = interface.findPidFlows(tonumber(pid_key))
   err_label = "PID"
   err_val = pid_key
  elseif (name_key ~= nil) then
   flows = interface.findNameFlows(name_key)
   err = "Name"
   err_val = name_key
  end
  
  num = 0;

  if(flows ~= nil) then
     for key, value in pairs(flows) do
	num = num + 1
     end
  end

  if(num == 0) then
     print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No traffic detected for this process, flow process expired, or process terminated.</div>")
  else
    if(host_key ~= nil) then
      name = getResolvedHostAddress(hostkey2hostinfo(host_key))
      if (name == nil) then
        name = host_key
      end
    end
   print [[
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav"> ]]

   if(pid_key ~= nil)then
      print [[ <li><a href="#">Pid: ]] print(pid_key) if(host_key ~= nil) then print(" - IP: "..name) end print [[ </a></li>]]
   elseif (name_key ~= nil)then
      print [[ <li><a href="#">]] print (getApplicationLabel(name_key)) if(host_key ~= nil) then print(" - IP: "..host_key) end print [[ </a></li>]]
   end
   
   if(page == "Protocols") then active=' class="active"' else active = "" end

if (pid_key ~= nil) then
   print('<li'..active..'><a href="?pid='.. pid_key) if(host_key ~= nil) then print("&host="..name) end print('&page=Protocols">Protocols</a></li>\n')
elseif (name_key ~= nil) then
   print('<li'..active..'><a href="?pid_name='.. name_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Protocols">Protocols</a></li>\n')
end

if (general_process == 1) then
  if(page == "Hosts") then active=' class="active"' else active = "" end
  if (pid_key ~= nil) then
    print('<li'..active..'><a href="?pid='.. pid_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Hosts">Hosts</a></li>\n')
  elseif (name_key ~= nil) then
   print('<li'..active..'><a href="?pid_name='.. name_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Hosts">Hosts</a></li>\n')
  end
end

if(page == "Flows") then active=' class="active"' else active = "" end
if (pid_key ~= nil) then
 print('<li'..active..'><a href="?pid='.. pid_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows">Flows</a></li>\n')
  elseif (name_key ~= nil) then
   print('<li'..active..'><a href="?pid_name='.. name_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows">Flows</a></li>\n')
  end

print [[ <li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a> ]]

-- End Tab Menu

print('</ul>\n\t</div>\n\t</nav>\n')


if(page == "Protocols") then

print [[
  <br>
  <!-- Left Tab -->

   <ul class="nav nav-tabs">
]]

print [[<li class="active"><a href="#l7" data-toggle="tab">L7 Protocols</a></li> ]]

print [[<li><a href="#l4" data-toggle="tab">L4 Protocols</a></li>]]

print [[
    </ul>
    
      <!-- Tab content-->
      <div class="tab-content">
]]

print [[
        <div class="tab-pane active" id="l7">
          <table class="table table-bordered table-striped">
            <tr>
              <th class="text-center">Top L7 Protocols</th>
              <td><div class="pie-chart" id="topL7"></div></td>
          </tr>
          </table>
        </div> <!-- Tab l7-->
]]

print [[

        <div class="tab-pane" id="l4">
          <table class="table table-bordered table-striped">
            <tr>
              <th class="text-center">Top L4 Protocols</th>
              <td><div class="pie-chart" id="topL4"></div></td>
          </tr>
          </table>
        </div> <!-- Tab l4-->
]]

print [[
      </div> <!-- End Tab content-->
   
     </table>
]]

 print [[
     
<script type='text/javascript'>
window.onload=function() {
   var refresh = 3000 /* ms */;
]]
if(pid_key ~= nil)then
   print [[ 
  do_pie("#topL7", ']]
print (ntop.getHttpPrefix())
print [[/lua/pid_stats.lua', { "pid": ]] print(pid_key) print [[, "pid_mode": "l7" ]] 
if (host_key ~= nil) then print(", host: \""..host_key.."\"") end
print [[
 }, "", refresh);
 do_pie("#topL4", ']]
print (ntop.getHttpPrefix())
print [[/lua/pid_stats.lua', { "pid": ]] print(pid_key) print [[, "pid_mode": "l4"  ]] 
if (host_key ~= nil) then print(", host: \""..host_key.."\"") end
print [[
 }, "", refresh);
  ]]
elseif (name_key ~= nil)then
    print [[ 
    do_pie("#topL7", ']]
print (ntop.getHttpPrefix())
print [[/lua/pid_stats.lua', { "name": "]] print(name_key) print [[", "pid_mode": "l7" ]] 
if (host_key ~= nil) then print(", host: \""..host_key.."\"") end
print [[
 }, "", refresh);
    do_pie("#topL4", ']]
print (ntop.getHttpPrefix())
print [[/lua/pid_stats.lua', { "name": "]] print(name_key) print [[", "pid_mode": "l4"  ]] 
if (host_key ~= nil) then print(", host: \""..host_key.."\"") end
print [[
 }, "", refresh); ]]
end
print [[	    
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

if(pid_key ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
   print("pid="..pid_key)
   num_param = num_param + 1
end

if(name_key ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
  print("pid_name="..name_key)
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

print('",')
-- Set the preference table
preference = tablePreferences("rows_number", _GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

print [[ showPagination: true,
         buttons: [ '<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Applications<span class="caret"></span></button> <ul class="dropdown-menu" id="flow_dropdown">]]

if (pid_key ~= nil) then
  print('<li><a href="'..ntop.getHttpPrefix()..'/lua/get_process_info.lua?pid='.. pid_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows">All Proto</a></li>')
end
if (name_key ~= nil) then
  print('<li><a href="'..ntop.getHttpPrefix()..'/lua/get_process_info.lua?pid_name='.. name_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows">All Proto</a></li>')
end

for key, value in pairsByKeys(stats["ndpi"], asc) do
   class_active = ''
   if(key == application) then
      class_active = ' class="active"'
   end


   if (pid_key ~= nil) then
    print('<li '..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/get_process_info.lua?pid='.. pid_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows&application=' .. key..'">'..key..'</a></li>')
    end

    if (name_key ~= nil) then
    print('<li '..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/get_process_info.lua?pid_name='.. name_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows&application=' .. key..'">'..key..'</a></li>')
    end


end


print("</ul> </div>' ],\n")


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/sflows_stats_top.inc")

prefs = ntop.getPrefs()

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/sflows_stats_bottom.inc")


elseif(page == "Hosts") then

print [[
  <br>
  <!-- Left Tab -->
  <div class="tabbable tabs-left">

    <ul class="nav nav-tabs">
]]

print [[<li class="active"><a href="#topHost" data-toggle="tab">Top Hosts</a></li> ]]

print [[
    </ul>
    
      <!-- Tab content-->
      <div class="tab-content">
]]

print [[
        <div class="tab-pane active" id="topHost">
          <table class="table table-bordered table-striped">
            <tr>
              <th class="text-center span3">Top Hosts Traffic</th>
              <td><div class="pie-chart" id="topHosts"></div></td>
          </tr>
          </table>
        </div> <!-- Tab l7-->
]]


print [[
      </div> <!-- End Tab content-->
    </div> <!-- End Left Tab -->
     </table>
]]

 print [[
<script type='text/javascript'>
window.onload=function() {
   var refresh = 3000 /* ms */;
]]

if(pid_key ~= nil)then
  print [[ 
    do_pie("#topHosts", ']]
print (ntop.getHttpPrefix())
print [[/lua/pid_stats.lua', { "pid": ]] print(pid_key) print [[", "pid_mode": "host" }, "", refresh);
  ]]
elseif (name_key ~= nil)then
  print [[ 
    do_pie("#topHosts", ']]
print (ntop.getHttpPrefix())
print [[/lua/pid_stats.lua', { "name": "]] print(name_key) print [[", "pid_mode": "host" }, "", refresh); 
    ]]
end

print [[      
}
</script>
]]

end -- If page

end -- Error one
end -- Error two

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
