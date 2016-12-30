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
print [[/lua/get_grouped_hosts_data.lua?grouped_by=mac]]

if(_GET["mac"] ~= nil) then
   print("&mac=".._GET["mac"])
end

if(_GET["mode"] ~= nil) then
  mode = _GET["mode"]
else
  mode = "hostsonly"  
end

print("&mode="..mode)

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/mac_stats_id.inc")

print [[ 
           $("#table-mac").datatable({
                        title: "Mac List",
			url: url_update , 
]]

if(_GET["mode"] ~= "hostsonly") then
 print('title: "Layer 2 Devices",\n')
else
 print('title: "All Layer 2 Devices",\n')
end

print ('rowCallback: function ( row ) { return mac_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("mac") ..'","' .. getDefaultTableSortOrder("mac").. '"] ],')

print('buttons: [ \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Filter MACs<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 90px;"><li><a href="')
   print(ntop.getHttpPrefix())
   print('/lua/mac_stats.lua?mode=hostsonly">Hosts Only</a></li><li><a href="')
   print(ntop.getHttpPrefix())
   print('/lua/mac_stats.lua?mode=all">All Devices</a></li><li><a href="')
   print(ntop.getHttpPrefix())
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
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }
				 },
			  ]]


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/mac_stats_top.inc")

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/mac_stats_bottom.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
