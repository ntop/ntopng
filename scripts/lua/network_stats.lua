--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("networks"))

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix().."/lua/network_stats.lua"

function getPageTitle()
   local t = i18n("network_stats.networks")

   if not isEmptyString(_GET["version"]) then
      t = i18n("network_stats.networks_traffic_with_ipver",{networks=t,ipver=_GET["version"]})
   end

   return t
end

print [[
      <div id="table-network"></div>
	 <script>
	 var url_update = "]]
print(getPageUrl(ntop.getHttpPrefix().."/lua/get_networks_data.lua"))
print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/network_stats_id.inc")

print [[
	 $("#table-network").datatable({
                        title: "Network List",
			url: url_update,]]

print('title: "'..getPageTitle()..'",\n')
print ('rowCallback: function ( row ) { return network_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("local_network") ..'","' .. getDefaultTableSortOrder("local_network").. '"] ],')


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
			     title: "]] print(i18n("network_stats.network_name")) print[[",
				 field: "column_id",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }
				 },
			  ]]

print [[
			     {
			     title: "]] print(i18n("chart")) print[[",
				 field: "column_chart",
				 sortable: false,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("hosts_stats.hosts")) print[[",
				 field: "column_hosts",
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

print(i18n("network_stats.note_overlapping_networks").."<ol>")
print("<li>"..i18n("network_stats.note_see_both_network_entries"))
print("<li>"..i18n("network_stats.note_broader_network").."</ol>")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
