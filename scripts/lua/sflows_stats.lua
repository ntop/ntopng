--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "flows"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

application = _GET["application"]
hosts       = _GET["hosts"]
aggregation = _GET["aggregation"]
key         = _GET["key"]
perPage     = _GET["perPage"]

stats = interface.getnDPIStats()
num_param = 0
print [[
      <hr>
      <div id="table-flows"></div>
   <script>
   var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_flows_data.lua]]

   if(application ~= nil) then
   print("?application="..application)
   num_param = num_param + 1
end

if(hosts ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
  print("hosts="..hosts)
  num_param = num_param + 1
end

if(aggregation ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
  print("aggregation="..aggregation)
  num_param = num_param + 1
end

if(key ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
  print("key="..key)
  num_param = num_param + 1
end

print ('";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")    
   print [[
   flow_rows_option["sprobe"] = true;
   $("#table-flows").datatable({
      url: url_update ,
]]
-- Set the preference table
preference = tablePreferences("rows_number", _GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

print [[
      rowCallback: function ( row ) { return flow_table_setID(row); },
	       showPagination: true,
	       buttons: [ '<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Applications<span class="caret"></span></button> <ul class="dropdown-menu" id="flow_dropdown">]]

print('<li><a href="'..ntop.getHttpPrefix()..'/lua/sflows_stats.lua">All Proto</a></li>')
for key, value in pairsByKeys(stats["ndpi"], asc) do
   class_active = ''
   if(key == application) then
      class_active = ' class="active"'
   end
   print('<li '..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/sflows_stats.lua?application=' .. key..'">'..key..'</a></li>')
end


print("</ul> </div>' ],\n")


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/sflows_stats_top.inc")

prefs = ntop.getPrefs()

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/sflows_stats_bottom.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
