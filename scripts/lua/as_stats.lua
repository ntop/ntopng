--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("as_stats.autonomous_systems"))

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
      <hr>
      <div id="table-as"></div>
	 <script>
	 var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_ases_data.lua]]

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/as_stats_id.inc")

print [[
	 $("#table-as").datatable({
                        title: "AS List",
			url: url_update ,
	 ]]

print('title: "' .. i18n("as_stats.autonomous_systems") .. '",\n')
print ('rowCallback: function ( row ) { return as_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("asn") ..'","' .. getDefaultTableSortOrder("asn").. '"] ],')


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
			     title: "]] print(i18n("as_number")) print[[",
				 field: "column_asn",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }
				 },
                         {
			     title: "]] print(i18n("chart")) print[[",
				 field: "column_chart",
				 sortable: false,
                             css: {
			        textAlign: 'center'
			     }
				 },
			  ]]

print [[
			     {
			     title: "]] print(i18n("hosts_stats.hosts")) print[[",
				 field: "column_hosts",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("show_alerts.alerts")) print[[",
				 field: "column_alerts",
				 sortable: false,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("name")) print[[",
				 field: "column_asname",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }

				 },
			     {
			     title: "]] print(i18n("seen_since")) print[[",
				 field: "column_since",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
]]

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
			     title: "]] print(i18n("throughput")) print[[",
				 field: "column_thpt",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }
				 },
			     {
			     title: "]] print(i18n("traffic")) print[[",
				 field: "column_traffic",
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
