--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "flows"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

application = _GET["application"]
hosts       = _GET["hosts"]
aggregation = _GET["aggregation"]
perPage     = _GET["perPage"]

stats = interface.getnDPIStats()
num_param = 0
print [[
      <hr>
      <div id="table-flows"></div>
   <script>
   var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_flows_data.lua]]

   if(application ~= nil) then
   print("?application="..application)
   num_param = num_param + 1
end

if(hosts ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
  print("hosts="..hosts)
  num_param = num_param + 1
end

if(aggregation ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
  print("aggregation="..aggregation)
  num_param = num_param + 1
end

print ('";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")    
   print [[
   flow_rows_option["sprobe"] = true;
   $("#table-flows").datatable({
      url: url_update ,
]]
-- Set the preference table
preference = tablePreferences("rows_number", _GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

print [[
      rowCallback: function ( row ) { return flow_table_setID(row); },
	       showPagination: true,
	       buttons: [ '<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("protocols")) print[[<span class="caret"></span></button> <ul class="dropdown-menu" id="flow_dropdown">]]

print('<li><a href="'..ntop.getHttpPrefix()..'/lua/sflows_stats.lua">'..i18n("flows_page.all_proto")..'</a></li>')
for key, value in pairsByKeys(stats["ndpi"], asc) do
   class_active = ''
   if(key == application) then
      class_active = ' class="active"'
   end
   print('<li '..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/sflows_stats.lua?application=' .. key..'">'..key..'</a></li>')
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

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
