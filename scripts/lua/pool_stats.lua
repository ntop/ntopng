--
-- (C) 2017-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

local active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
      <hr>
      <div id="table-pool"></div>
	 <script>
	 var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_grouped_hosts_data.lua?grouped_by=pool_id]]

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/pool_stats_id.inc")

print [[
	 $("#table-pool").datatable({
			url: url_update ,
	 ]]

print('title: "'
	 ..i18n(ternary(have_nedge, "nedge.users_list", "pool_stats.host_pool_list"))
	 ..'",\n')
print ('rowCallback: function ( row ) { return pool_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("pool_id") ..'","' .. getDefaultTableSortOrder("pool_id").. '"] ],')


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
            },{
              title: "]] print(i18n(ternary(have_nedge, "nedge.user", "host_pools.pool_name"))) print[[",
              field: "column_id",
              sortable: false,
                css: {
                  textAlign: 'left'
              }
            },{
              title: "]] print(i18n("chart")) print[[",
              field: "column_chart",
]]
if not ntop.isPro() then
   print('hidden: true,')
end
print[[
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
			     title: "]] print(i18n("flows")) print[[",
				 field: "column_num_flows",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("if_stats_overview.dropped_flows")) print[[",
				 field: "column_num_dropped_flows",
				 sortable: true,
                                 hidden: ]]
if isBridgeInterface(interface.getStats()) then
   print("false")
else
   print("true")
end
print[[,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("show_alerts.alerts")) print[[",
				 field: "column_alerts",
				 sortable: true,
                             css: {
			        textAlign: 'center'
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
