--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[


<ul class="breadcrumb">
  <li><A HREF="]]
print (ntop.getHttpPrefix())
print [[/lua/flows_stats.lua">]] print(i18n("flows")) print [[</A> </li>
]]


print("<li>"..i18n("port_details.l4_port")..": ".._GET["port"].."</li></ul>")

print [[
      <div id="table-hosts"></div>
	 <script>
	 $("#table-hosts").datatable({
				  ]]
				  print("url: \""..ntop.getHttpPrefix().."/lua/get_flows_data.lua?port=" .. _GET["port"])
				  if(_GET["host"] ~= nil) then print("&host=".._GET["host"]) end
				  print("\",\n")


print [[
	       showPagination: true,
	       title: "]]
	       if(_GET["host"] ~= nil) then 
	          print(i18n("port_details.active_flows_for_host_and_port",{host=_GET["host"],port=_GET["port"]}))
	       else
		  symbolic_port = getservbyport(_GET["port"])
		  if(symbolic_port ~= _GET["port"]) then
		     print(i18n("port_details.active_flows_on_port_symbolic",{port=_GET["port"],symbolic_port=symbolic_port}))
		  else
		     print(i18n("port_details.active_flows_on_port",{port=_GET["port"]}))
  		  end
	       end
		print [[",
	        columns: [
			     {
			     title: "]] print(i18n("info")) print [[",
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
			     title: "]] print(i18n("details.l4_proto")) print[[",
				 field: "column_proto_l4",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 }, {]]

			       ifstats = interface.getStats()

if(ifstats.sprobe) then
   print('title: "'..i18n("details.source_id")..'",\n')
else
   print('title: "'..i18n("vlan")..'",\n')
end

print [[
				 field: "column_vlan",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }

				 },
]]

print [[
			     {
			     title: "]] print(i18n("client")) print[[",
				 field: "column_client",
				 sortable: true,
				 },
			     {
			     title: "]] print(i18n("server")) print[[",
				 field: "column_server",
				 sortable: true,
				 },
			     {
			     title: "]] print(i18n("duration")) print[[",
				 field: "column_duration",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			       }
			       },
			     {
			     title: "]] print(i18n("bytes")) print[[",
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
