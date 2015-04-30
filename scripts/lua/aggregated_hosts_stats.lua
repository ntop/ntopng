--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


print [[
      <hr>
      <div id="table-hosts"></div>
	 <script>
   var url_update =]]
print(ntop.getHttpPrefix())
print[["/lua/get_hosts_data.lua?aggregated=1]]
          if(_GET["protocol"]) then print("&protocol=".._GET["protocol"]) end
          if(_GET["client"]) then print("&client=".._GET["client"]) end
          if(_GET["aggregation"] ~= nil) then print("&aggregation=".._GET["aggregation"]) end
    print ('";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/aggregated_hosts_stats_id.inc")

print [[
   $("#table-hosts").datatable({
      title: "Aggregations",
      url: url_update ,
      showPagination: true,
      ]]

-- Parse and set a unique id for all rows and enable the automatic update of the table
print ('rowCallback: function ( row ) { return aggregated_host_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

print [[
         buttons: [ '<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Aggregations<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 110px;">]]

print('<li><a href='..ntop.getHttpPrefix()..'"/lua/aggregated_hosts_stats.lua">All</a></li>')

families = interface.getAggregationFamilies()
for key,v in pairs(families["families"]) do
   print('<li><a href='..ntop.getHttpPrefix()..'"/lua/aggregated_hosts_stats.lua?protocol=' .. v..'">'..key..'</a></li>')

--   for key1,v1 in pairs(families["aggregations"]) do
--      print('<li><a href="'..ntop.getHttpPrefix()..'/lua/aggregated_hosts_stats.lua?protocol=' .. v..'&aggregation='..v1..'">- '..key..' ('..key1..')</a></li>')
--   end
end

print("</ul> </div>' ],\n")


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/aggregated_hosts_stats_top.inc")

prefs = ntop.getPrefs()

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/aggregated_hosts_stats_bottom.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
