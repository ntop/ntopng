--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "flows"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

application = _GET["application"]
application_filter = ""
hosts = _GET["hosts"]
host = _GET["host"]
vhost = _GET["vhost"]
flowhosts_type = _GET["flowhosts_type"]
flowhosts_type_filter = ""
ipversion = _GET["version"]
ipversion_filter = ""

network_id = _GET["network"]

prefs = ntop.getPrefs()
interface.select(ifname)
ifstats = interface.getStats()
ndpistats = interface.getnDPIStats()

local filter_base_url = ntop.getHttpPrefix() .. "/lua/flows_stats.lua"
local filter_url_params = {}

function getPageUrl(params, base_url)
   local base_url = base_url or filter_base_url
   local params = params or filter_url_params
   for _,_ in pairs(params) do
      return base_url .. "?" .. table.tconcat(params, "=", "&")
   end
   return base_url
end

if (network_id ~= nil) then
network_name = ntop.getNetworkNameById(tonumber(network_id))
url = ntop.getHttpPrefix()..'/lua/flows_stats.lua?network='..network_id

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]
print("<li><a href=\"#\"> Network "..network_name)
print("</a></li>\n")

page = _GET["page"]

if(page == "flows") then
  print("<li class=\"active\"><a href=\"#\">Flows</a></li>\n")
else
  print("<li><a href=\""..url.."&page=flows\">Flows</a></li>")
end
if (page == "historical") then
  print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i></a></li>\n")
else
  print("<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
   ]]
end

if (page == "flows" or page == nil) then

print [[
      <hr>
      <div id="table-flows"></div>
	 <script>
   var url_update = "]]

if(application ~= nil) then
   filter_url_params["application"] = application
   application_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if(host ~= nil) then
  filter_url_params["host"] = host
end

if(vhost ~= nil) then
  filter_url_params["vhost"] = vhost
end

if(hosts ~= nil) then
  filter_url_params["hosts"] = hosts
end

if(ipversion ~= nil) then
  filter_url_params["version"] = ipversion
  ipversion_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if(network_id ~= nil) then
  filter_url_params["network"] = network_id
end

if(flowhosts_type ~= nil) then
  filter_url_params["flowhosts_type"] = flowhosts_type
  flowhosts_type_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

print(getPageUrl(filter_url_params, ntop.getHttpPrefix().."/lua/get_flows_data.lua"))

print ('";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")
-- Set the flow table option

if(ifstats.vlan) then print ('flow_rows_option["vlan"] = true;\n') end

   print [[
	 var table = $("#table-flows").datatable({
			url: url_update , ]]
print ('rowCallback: function ( row ) { return flow_table_setID(row); },\n')

preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- prepare the page title that slighly changes depending on
-- the kind of interface
local active_msg = "Active "

if not interface.isPacketInterface() then
   active_msg = "Recently "..active_msg
elseif interface.isPcapDumpInterface() then
   active_msg = ""
end

active_msg = active_msg..(application or vhost or "").." Flows"

if(network_name ~= nil) then
   active_msg = active_msg.." [ Network "..network_name.." ]"
end

print(" title: \""..active_msg)


print [[",
         showFilter: true,
         showPagination: true,
]]

-- Automatic default sorted. NB: the column must be exists.
print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')

print ('buttons: [')

-- begin buttons

-- Local / Remote hosts selector
local flowhosts_type_params = table.clone(filter_url_params)
flowhosts_type_params["flowhosts_type"] = nil

print[['\
   <div class="btn-group">\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Hosts]] print(flowhosts_type_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a href="]] print(getPageUrl(flowhosts_type_params)) print[[">All Hosts</a></li>\]]
for _, htype in ipairs({
   {"local_only", "Local Only"},
   {"remote_only", "Remote Only"},
   {"local_origin_remote_target", "Local Client - Remote Server"},
   {"remote_origin_local_target", "Local Server - Remote Client"}}) do

   flowhosts_type_params["flowhosts_type"] = htype[1]
   print[[<li]]
   if htype[1] == flowhosts_type then print(' class="active"') end
   print[[><a href="]] print(getPageUrl(flowhosts_type_params)) print[[">]] print(htype[2]) print[[</a></li>]]
end
print[[\
      </ul>\
   </div>\
']]

-- L7 Application
print(', \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Applications ' .. application_filter .. '<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" id="flow_dropdown">')
print('<li><a href="')
local application_filter_params = table.clone(filter_url_params)
application_filter_params["application"] = nil
print(getPageUrl(application_filter_params))
print('">All Proto</a></li>')

for key, value in pairsByKeys(ndpistats["ndpi"], asc) do
   class_active = ''
   if(key == application) then
      class_active = ' class="active"'
   end
   print('<li '..class_active..'><a href="')
   application_filter_params["application"] = key
   print(getPageUrl(application_filter_params))
   print('">'..key..'</a></li>')
end

print("</ul> </div>'")

-- Ip version selector
local ipversion_params = table.clone(filter_url_params)
ipversion_params["version"] = nil

print[[, '\
   <div class="btn-group pull-right">\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">IP Version]] print(ipversion_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a href="]] print(getPageUrl(ipversion_params)) print[[">All Versions</a></li>\
         <li]] if ipversion == "4" then print(' class="active"') end print[[><a href="]] ipversion_params["version"] = "4"; print(getPageUrl(ipversion_params)); print[[">IPv4 Only</a></li>\
         <li]] if ipversion == "6" then print(' class="active"') end print[[><a href="]] ipversion_params["version"] = "6"; print(getPageUrl(ipversion_params)); print[[">IPv6 Only</a></li>\
      </ul>\
   </div>\
']]

-- end buttons

print(" ],\n")

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_top.inc")

if(ifstats.vlan) then
print [[
           {
           title: "VLAN",
         field: "column_vlan",
         sortable: true,
                 css: {
              textAlign: 'center'
           }
         },
]]
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_middle.inc")

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_bottom.inc")
end

if (page == "historical" and network_name ~= nil) then
  local netname_format = string.gsub(network_name, "_", "/")
  local rrd_file = _GET["rrd_file"]
  if (rrd_file == nil or rrd_file == "all") then
    rrd_file = "all"
  else
    rrd_file = getPathFromKey(netname_format).."/"..rrd_file
  end
  drawRRD(ifstats.id, nil, rrd_file, "1d", url.."&page=historical", 1, os.time() , "", nil)
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
