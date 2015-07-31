--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[


<ul class="breadcrumb">
  <li><A HREF=]]
print (ntop.getHttpPrefix())
print [[/lua/flows_stats.lua>Flows</A> <span class="divider">/</span></li>
]]


print("<li>L4 Port: ".._GET["port"].."</li></ul>")

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
	       title: "Active Flows ]]
	       if(_GET["host"] ~= nil) then 
	         print("for ".._GET["host"]..":".._GET["port"])
	      else
		 symbolic_port = getservbyname(_GET["port"], _GET["proto"])
		  print("on Port ".._GET["port"])
		  if(symbolic_port ~= _GET["port"]) then
		     print(" [".. symbolic_port .."]")
		  end
	       end
		print [[",
	        columns: [
			     {
			     title: "Info",
				 field: "column_key",
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "Application",
				 field: "column_ndpi",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "L4 Proto",
				 field: "column_proto_l4",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 }, {]]

ifstats = interface.getStats()

if(ifstats.iface_sprobe) then
   print('title: "Source Id",\n')
else
   print('title: "VLAN",\n')
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
			     title: "Client",
				 field: "column_client",
				 sortable: true,
				 },
			     {
			     title: "Server",
				 field: "column_server",
				 sortable: true,
				 },
			     {
			     title: "Duration",
				 field: "column_duration",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			       }
			       },
			     {
			     title: "Bytes",
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
