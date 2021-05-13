--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.countries)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_page_title(i18n("countries"))

print [[
	  <div id="table-country"></div>
	 <script>
	 var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_countries_data.lua]]

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/country_stats_id.inc")

print [[
	 $("#table-country").datatable({
			title: "Country List",
			url: url_update ,
	 ]]

print('title: "",\n')
print ('rowCallback: function ( row ) { return country_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("country") ..'","' .. getDefaultTableSortOrder("country").. '"] ],')


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
			     title: "]] print(i18n("name")) print[[",
				 field: "column_id",
				 sortable: true,
			     css: {
				textAlign: 'left'
			     }

				 }, {
					title: "]] print(i18n("chart")) print[[",
					field: "column_chart",
					sortable: false,]]

local charts_enabled = areCountryTimeseriesEnabled(interface.getId())

if not charts_enabled then
   print("hidden: true,\n")
end

print[[
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
				 /* TODO: alerts not implemented */
				 hidden: true,
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

				 }, {
			     title: "]] print(i18n("score")) print[[",
				 field: "column_score",
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
