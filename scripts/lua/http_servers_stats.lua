--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
      <hr>
      <div id="table-http"></div>
	 <script>
	 var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_http_hosts_data.lua]]

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/http_servers_stats_id.inc")

print [[
	 $("#table-http").datatable({
                        title: "Local HTTP Servers",
			url: url_update ,
	 ]]

print('title: "Local HTTP Servers",\n')
print ('rowCallback: function ( row ) { return http_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("http") ..'","' .. getDefaultTableSortOrder("http").. '"] ],')


print [[
	       showPagination: true,
	        columns: [
           {
                                title: "Key",
                                field: "key",
                                hidden: true,
                                css: {
                                   textAlign: 'center'
                                }
           },
	     {
			     title: "HTTP Virtual Host",
				 field: "column_http_virtual_host",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }

				 },
	     {
			     title: "HTTP Server IP",
				 field: "column_server_ip",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
			  ]]


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/http_servers_stats_top.inc")

print [[
			     ]
	       });


       </script>

]]
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
