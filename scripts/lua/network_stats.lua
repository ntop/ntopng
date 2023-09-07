--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")
local ui_utils = require("ui_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.networks)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix().."/lua/network_stats.lua"

function getPageTitle()
   local t = i18n("network_stats.networks")

   if not isEmptyString(_GET["version"]) then
      t = i18n("network_stats.networks_traffic_with_ipver",{networks=t,ipver=_GET["version"]})
   end

   return t
end

page_utils.print_page_title(getPageTitle())

-- ##############################

if(ntop.isPro()) then
   local networks_stats = interface.getNetworksStats()
   local numNetworks = table.len(networks_stats)

   if(numNetworks > 0) then
      local template_utils = require "template_utils"
      
      template_utils.render("pages/networks_map.html", {
			       url = ntop.getHttpPrefix()..'/lua/pro/rest/v2/get/host/top/network_hosts_score.lua',
			       prefix = ntop.getHttpPrefix()
      })
   end
end

-- ##############################

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

print('title: "",\n')
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
				 hidden: ]] print(ternary(areInterfaceTimeseriesEnabled(interface.getId()), "false", "true")) print[[,
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
         {
         title: "]] print(i18n("score")) print[[",
       field: "column_score",
       sortable: true,
                           css: {
            textAlign: 'center'
         },
       },
       {
       title: "]] print(i18n("host_score_ratio")) print[[",
     field: "column_host_score_ratio",
     sortable: false,
                         css: {
          textAlign: 'center'
       },
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

print(ui_utils.render_notes({
	{content = i18n("network_stats.note_see_both_network_entries")},
	{content = i18n("network_stats.note_broader_network")}
}, i18n("network_stats.note_overlapping_networks"), true))

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
