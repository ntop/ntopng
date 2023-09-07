--
-- (C) 2013-23 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')


page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.autonomous_systems)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_page_title(i18n("as_stats.autonomous_systems"))

print [[
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

print('title: "",\n')
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
				 hidden: ]] print(ternary(areASTimeseriesEnabled(interface.getId()), "false", "true")) print[[,
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
          title: "]] print(i18n("score")) print[[",
          field: "column_score",
          sortable: true,
                      css: {
          textAlign: 'center'
            }
          },
          {
           title: "]] print(i18n("host_score_ratio")) print[[",
           field: "column_host_score_ratio",
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
         {
         title: "]] print(i18n("flow_details.alerted_flows")) print[[",
       field: "column_alerted_flows",
       sortable: true,
                           css: {
            textAlign: 'center'
         },
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
