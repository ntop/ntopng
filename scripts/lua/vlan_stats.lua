--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

if (group_col == nil) then
   group_col = "asn"
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
      <hr>
      <div id="table-vlan"></div>
	 <script>
	 var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_vlans_data.lua]]

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/vlan_stats_id.inc")

print [[
	 $("#table-vlan").datatable({
                        title: "VLAN List",
			url: url_update ,
	 ]]

print('title: "'..i18n("vlan_stats.vlans")..'",\n')
print ('rowCallback: function ( row ) { return vlan_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("vlan") ..'","' .. getDefaultTableSortOrder("vlan").. '"] ],')


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
			     title: "]] print(i18n("vlan_stats.vlan_id")) print[[",
				 field: "column_vlan",
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
			     {
			     title: "]] print(i18n("show_alerts.alerts")) print[[",
				 field: "column_alerts",
				 sortable: false,
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
