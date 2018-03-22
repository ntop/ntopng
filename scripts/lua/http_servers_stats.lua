--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

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

print('title: "' .. i18n("http_servers_stats.local_http_servers") .. '",\n')
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
			     title: "]] print(i18n("http_servers_stats.http_virtual_host")) print[[",
				 field: "column_http_virtual_host",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }

				 },
	     {
			     title: "]] print(i18n("http_servers_stats.http_server_ip")) print[[",
				 field: "column_server_ip",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
			  ]]

print [[
			     {
			     title: "]] print(i18n("http_servers_stats.bytes_sent")) print[[",
				 field: "column_bytes_sent",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("http_servers_stats.bytes_received")) print[[",
				 field: "column_bytes_rcvd",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },

			     {
			     title: "]] print(i18n("http_servers_stats.total_requests")) print[[",
				 field: "column_http_requests",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("http_servers_stats.actual_requests")) print[[",
				 field: "column_act_num_http_requests",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
]]

print [[
			     ]
	       });


       </script>

]]
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
