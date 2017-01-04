--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

if (group_col == nil) then
   group_col = "mac"
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "devices_stats"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
      <hr>
      <div id="table-mac"></div>
	 <script>
	 var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_macs_data.lua?]]

local skipSpecial = false
local skipFilter = ""
if(_GET["skipSpecial"] ~= nil) then
   skipSpecial = true
   skipFilter = '<span class="glyphicon glyphicon-filter"></span>'
   print("skipSpecial=".._GET["skipSpecial"])
end

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/mac_stats_id.inc")

print [[ 
           $("#table-mac").datatable({
                        title: "Mac List",
			url: url_update , 
]]

if skipSpecial then
 print('title: "Layer 2 Devices",\n')
else
 print('title: "All Layer 2 Devices",\n')
end

print ('rowCallback: function ( row ) { return mac_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("macs") ..'","' .. getDefaultTableSortOrder("macs").. '"] ],')

print('buttons: [ \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Filter MACs'..skipFilter..'<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 90px;"><li><a href="')
   print(ntop.getHttpPrefix())
   print('/lua/mac_stats.lua?skipSpecial=true">Hosts Only</a></li>')
   print('<li><a href="')
   print(ntop.getHttpPrefix())
   print('/lua/mac_stats.lua">All Devices</a></li>')
   print("</div>' ],")

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
			     title: "MAC Address",
				 field: "column_link",
				 sortable: false,
                             css: {
			        textAlign: 'left'
			     }
				 },
                         {
			     title: "Manufacturer",
				 field: "column_manufacturer",
				 sortable: false,
                             css: {
			        textAlign: 'left'
			     }
				 },
			  ]]


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/mac_stats_top.inc")

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/mac_stats_bottom.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
