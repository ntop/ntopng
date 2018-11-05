--
-- (C) 2014-15-15 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

local page = _GET["page"]

if(page == nil) then page = "username_processes" end
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local user_key    = _GET["username"]
local host_info    = url2hostinfo(_GET)
local uid         = _GET["uid"]
local application = _GET["application"]
local name
local refresh_rate

if ntop.isnEdge() then
  refresh_rate = 5
else
   refresh_rate = getInterfaceRefreshRate(interface.getStats()["id"])
end

if(user_key == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("user_info.missing_user_name_message").."</div>")
else
   if host_info and host_info["host"] then
      name = getResolvedAddress(hostkey2hostinfo(host_info["host"]))
      if (name == nil) then
	 name = host_info["host"]
      end
   end
  print [[
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
      <ul class="nav navbar-nav">
	    <li><a href="#">]]

  if host_info then
     print(string.format("%s: %s", i18n("host_details.host"), name))
  end

  print [[ <i class="fa fa-linux fa-lg"></i> ]] print(user_key)

  print [[  </a></li>]]


if(page == "username_processes") then active=' class="active"' else active = "" end
print('<li'..active..'><a href="?username='.. user_key..'&uid='..uid)
if host_info then
   print('&'..hostinfo2url(host_info))
end
print('&page=username_processes">'..i18n("user_info.processes")..'</a></li>\n')

if(page == "username_ndpi") then active=' class="active"' else active = "" end
print('<li'..active..'><a href="?username='.. user_key..'&uid='..uid)
if host_info then
   print('&'..hostinfo2url(host_info))
end
print('&page=username_ndpi">'..i18n("protocols")..'</a></li>\n')

if(page == "flows") then active=' class="active"' else active = "" end
print('<li'..active..'><a href="?username='.. user_key..'&uid='..uid)
if host_info then
   print('&'..hostinfo2url(host_info))
end
print('&page=flows">'..i18n("flows")..'</a></li>\n')


print('</ul>\n\t</div>\n\t\t</nav>\n')

if(page == "username_processes") then
print [[
    <table class="table table-bordered table-striped">
      <tr><th class="text-left">
      ]] print(i18n("user_info.processes_overview")) print[[
        <td><div class="pie-chart" id="topProcesses"></div></td>
      
      </th>
    </tr>]]

print [[
      </table>
<script type='text/javascript'>
window.onload=function() {
   var refresh = ]] print(refresh_rate..'') print[[000 /* ms */;
		    do_pie("#topProcesses", ']]
print (ntop.getHttpPrefix())
print [[/lua/get_username_data.lua', { uid: "]] print(uid) print [[", username_data: "processes" ]] 
if (host_info ~= nil) then print(", "..hostinfo2json(host_info)) end
print [[
 }, "", refresh);
}
</script>
]]

elseif(page == "username_ndpi") then

   print [[

  <table class="table table-bordered table-striped">
    <tr>
      <th class="text-left" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("ndpi_page.application_protocol")})) print[[</th>
      <td>
        <div class="pie-chart" id="topApplicationProtocols"></div>
      </td>
      <td colspan=2>
        <div class="pie-chart" id="topApplicationBreeds"></div>
      </td>
    </tr>
    <tr>
      <th class="text-left" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("ndpi_page.application_protocol_category")})) print[[</th>
      <td colspan=2>
        <div class="pie-chart" id="topApplicationCategories"></div>
      </td>
    </tr>
  </table>

        <script type='text/javascript'>
               var refresh = ]] print(refresh_rate..'') print[[000 /* ms */;
	       window.onload=function() {]]

   print[[ do_pie("#topApplicationProtocols", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/get_username_data.lua', { uid: "]] print(uid) print [[", username_data: "applications" ]] 
   if (host_info ~= nil) then print(", "..hostinfo2json(host_info)) end
   print [[ }, "", refresh); ]]

   print[[ do_pie("#topApplicationCategories", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/get_username_data.lua', { uid: "]] print(uid) print [[", username_data: "categories" ]] 
   if (host_info ~= nil) then print(", "..hostinfo2json(host_info)) end
   print [[ }, "", refresh); ]]

   print[[do_pie("#topApplicationBreeds", ']]
   print [[/lua/get_username_data.lua', { uid: "]] print(uid) print [[", username_data: "breeds" ]] 
   if (host_info ~= nil) then print(", "..hostinfo2json(host_info)) end
   print [[ }, "", refresh);]]

   print[[
				}

	    </script>
]]

elseif(page == "flows") then

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

print('<li><a href="'..ntop.getHttpPrefix()..'/lua/get_user_info.lua?username='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=flows">'..i18n("flows_page.all_proto")..'</a></li>')
for key, value in pairsByKeys(stats["ndpi"], asc) do
   class_active = ''
   if(key == application) then
      class_active = ' class="active"'
   end
   print('<li '..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/get_user_info.lua?username='.. user_key) if(host_key ~= nil) then print("&host="..host_key) end print('&page=flows&application=' .. key..'">'..key..'</a></li>')
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
