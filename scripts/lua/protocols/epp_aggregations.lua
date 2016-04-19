--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "protocols_stats"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

aggregation = _GET["aggregation"]
if(aggregation == nil) then aggregation = 1 end

tracked = _GET["tracked"]
if(tracked == nil) then tracked = 0 else tracked = tonumber(tracked) end


print [[
      <hr>
      <div id="table-hosts"></div>
    <script>
   var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_hosts_data.lua?aggregation=1&protocol=38]] -- 38 == EPP
   if(_GET["client"]) then print("&client=".._GET["client"]) end
   if(_GET["tracked"]) then print("&tracked=".._GET["tracked"]) end
   print("&aggregation="..aggregation)
   print ('";')

   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/aggregated_hosts_stats_id.inc")

print [[
   $("#table-hosts").datatable({
      url: url_update,
      ]]

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

print [[
      showPagination: true,
      ]]

-- Uncomment this line to enable the automatic update of the table
print ('rowCallback: function ( row ) { return aggregated_host_table_setID(row); },')

print [[buttons: [ '<div class="btn-group"><button class="btn dropdown-toggle" data-toggle="dropdown">Aggregations<span class="caret"></span></button> <ul class="dropdown-menu">]]

families = interface.getAggregationFamilies()
for key,v in pairs(families["families"]) do

   for key1,v1 in pairs(families["aggregations"]) do
      print('<li><a href="'..ntop.getHttpPrefix()..'/lua/protocols/epp_aggregations.lua?protocol=' .. v..'&aggregation='..v1..'">- '..key..' ('..key1..')</a></li>')
   end
end

print("</ul> </div>' ],\n")


aggregation = tonumber(aggregation)

if(aggregation == 1) then
   print("title: \"EPP Servers\",\n")
   elseif((aggregation == 2) and (tracked == 1)) then
   print("title: \"EPP Existing Domains\",\n")
   elseif(aggregation == 2) then
   print("title: \"EPP Unknown Domains\",\n")
   elseif(aggregation == 4) then
   print("title: \"EPP Registrars\",\n")
else
   print("title: \"Aggregations\",\n")
end


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/aggregated_hosts_stats_top.inc")

prefs = ntop.getPrefs()

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/aggregated_hosts_stats_bottom.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
