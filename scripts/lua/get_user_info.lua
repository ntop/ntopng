--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

page = _GET["page"]
if(page == nil) then page = "UserApps" end
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

user_key = _GET["username"]
host_key = _GET["host"]
application = _GET["application"]

if(user_key == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("user_info.missing_user_name_message").."</div>")
else
  if(host_key ~= nil) then
    name = getResolvedAddress(hostkey2hostinfo(host_key))
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
print('<li'..active..'><a href="?username='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=UserApps">'..i18n("applications")..'</a></li>\n')

if(page == "UserProtocols") then active=' class="active"' else active = "" end
print('<li'..active..'><a href="?username='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=UserProtocols">'..i18n("protocols")..'</a></li>\n')

if(page == "Flows") then active=' class="active"' else active = "" end
print('<li'..active..'><a href="?username='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows">'..i18n("flow")..'</a></li>\n')


print('</ul>\n\t</div>\n\t\t</nav>\n')


if(page == "UserApps") then
print [[
    <table class="table table-bordered table-striped">
      <tr><th class="text-center">
      <h4>]] print(i18n("user_info.top_applications")) print[[</h4>
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
print [[/lua/user_stats.lua', { username: "]] print(user_key) print [[", mode: "apps" ]] 
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
      <li class="active"><a href="#l7" data-toggle="tab">]] print(i18n("l7_protocols")) print[[</a></li>
      <li><a href="#l4" data-toggle="tab">]] print(i18n("l4_protocols")) print[[</a></li>
    </ul>
    
      <!-- Tab content-->
      <div class="tab-content">

        <div class="tab-pane active" id="l7">
          <table class="table table-bordered table-striped">
            <tr>
              <th class="text-center">]] print(i18n("user_info.top_l7_protocols")) print[[</th>
              <td><div class="pie-chart" id="topL7"></div></td>
          </tr>
          </table>
        </div> <!-- Tab l7-->


        <div class="tab-pane" id="l4">
          <table class="table table-bordered table-striped">
            <tr>
              <th class="text-center">]] print(i18n("user_info.top_l4_protocols")) print[[</th>
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
print [[/lua/user_stats.lua', { username: "]] print(user_key) print [[", mode: "l7" ]] 
if (host_key ~= nil) then print(", host: \""..host_key.."\"") end
print [[
 }, "", refresh);
		    do_pie("#topL4", ']]
print (ntop.getHttpPrefix())
print [[/lua/user_stats.lua', { username: "]] print(user_key) print [[", mode: "l4" ]] 
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
   print("username="..user_key)
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
         buttons: [ '<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("applications")) print[[<span class="caret"></span></button> <ul class="dropdown-menu" id="flow_dropdown">]]

print('<li><a href="'..ntop.getHttpPrefix()..'/lua/get_user_info.lua?username='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows">'..i18n("flows_page.all_proto")..'</a></li>')
for key, value in pairsByKeys(stats["ndpi"], asc) do
   class_active = ''
   if(key == application) then
      class_active = ' class="active"'
   end
   print('<li '..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/get_user_info.lua?username='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=Flows&application=' .. key..'">'..key..'</a></li>')
end


print("</ul> </div>' ],\n")


print [[
	       title: "]] print(i18n("sflows_stats.active_flows")) print[[",
	        columns: [
			     {
         field: "key",
         hidden: true
         	},
         {
			     title: "]] print(i18n("info")) print[[",
				 field: "column_key",
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("application")) print[[",
				 field: "column_ndpi",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("sflows_stats.l4_proto")) print[[",
				 field: "column_proto_l4",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
  			     {
			     title: "]] print(i18n("sflows_stats.client_process")) print[[",
				 field: "column_client_process",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("sflows_stats.client_peer")) print[[",
				 field: "column_client",
				 sortable: true,
				 },
			     {
                             title: "]] print(i18n("sflows_stats.server_process")) print[[",
				 field: "column_server_process",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("sflows_stats.server_peer")) print[[",
				 field: "column_server",
				 sortable: true,
				 },
			     {
			     title: "]] print(i18n("duration")) print[[",
				 field: "column_duration",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			       }
			       },

]]

prefs = ntop.getPrefs()

print [[
			     {
			     title: "]] print(i18n("breakdown")) print[[",
				 field: "column_breakdown",
				 sortable: false,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("sflows_stats.total_bytes")) print[[",
				 field: "column_bytes",
				 sortable: true,
	 	             css: { 
			        textAlign: 'right'
			     }
				 }
			     ]
	       });
       </script>
]]




end -- If page



end



dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
