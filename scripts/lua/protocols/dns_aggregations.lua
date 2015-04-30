--
-- (C) 2013-15 - ntop.org
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


print [[
      <hr>
      <div id="table-hosts"></div>
	 <script>
   var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_hosts_data.lua?aggregated=1&protocol=5]] -- 5 == DNS
   if(_GET["client"]) then print("&client=".._GET["client"]) end
   print ('";')

   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/aggregated_hosts_stats_id.inc")

print [[
   $("#table-hosts").datatable({
      title: "DNS Queries",
      url: url_update ,
      ]]

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

print [[
      showPagination: true,
      ]]

print ('rowCallback: function ( row ) { return aggregated_host_table_setID(row); },')


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/aggregated_hosts_stats_top.inc")

prefs = ntop.getPrefs()

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/aggregated_hosts_stats_bottom.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
