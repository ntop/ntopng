--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "flows"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- nDPI application and category
local application = _GET["application"]
local application_filter = ""
local category = _GET["category"]
local category_filter = ""

local hosts = _GET["hosts"]
local host = _GET["host"]
local vhost = _GET["vhost"]
local flowhosts_type = _GET["flowhosts_type"]
local flowhosts_type_filter = ""
local ipversion = _GET["version"]
local ipversion_filter = ""
local vlan = _GET["vlan"]
local vlan_filter = ""

-- remote exporters address and interfaces
local deviceIP = _GET["deviceIP"]
local inIfIdx  = _GET["inIfIdx"]
local outIfIdx = _GET["outIfIdx"]
local deviceIP_filter = ""
local inIfIdx_filter  = ""
local outIfIdx_filter = ""

local traffic_type = _GET["traffic_type"]
local traffic_type_filter = ""
local flow_status = _GET["flow_status"]
local flow_status_filter = ""
local port = _GET["port"]

local network_id = _GET["network"]

local client_asn = _GET["client_asn"]
local server_asn = _GET["server_asn"]

local prefs = ntop.getPrefs()
interface.select(ifname)
local ifstats = interface.getStats()
local ndpistats = interface.getnDPIStats()
local ndpicatstats = ifstats["ndpi_categories"]

local base_url = ntop.getHttpPrefix() .. "/lua/flows_stats.lua"
local page_params = {}

if (page == "flows" or page == nil) then

print [[
      <hr>
      <div id="table-flows"></div>
	 <script>
   var url_update = "]]

if(category ~= nil) then
   page_params["category"] = category
   category_filter = '<span class="glyphicon glyphicon-filter"></span>'
   application_filter = ""
elseif(application ~= nil) then
   page_params["application"] = application
   application_filter = '<span class="glyphicon glyphicon-filter"></span>'
   category_filter = ""
end

if(host ~= nil) then
  page_params["host"] = host
end

if(vhost ~= nil) then
  page_params["vhost"] = vhost
end

if(hosts ~= nil) then
  page_params["hosts"] = hosts
end

if(port ~= nil) then
  page_params["port"] = port
end

if(ipversion ~= nil) then
  page_params["version"] = ipversion
  ipversion_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if(deviceIP ~= nil) then
   page_params["deviceIP"] = deviceIP
   deviceIP_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if(inIfIdx ~= nil) then
   page_params["inIfIdx"] = inIfIdx
   inIfIdx_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if(outIfIdx ~= nil) then
   page_params["outIfIdx"] = outIfIdx
   outIfIdx_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if(vlan ~= nil) then
  page_params["vlan"] = vlan
  vlan_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if(traffic_type ~= nil) then
   page_params["traffic_type"] = traffic_type
   traffic_type_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if(flow_status ~= nil) then
   page_params["flow_status"] = flow_status
   flow_status_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if(network_id ~= nil) then
  page_params["network"] = network_id
end

if(client_asn ~= nil) then
   page_params["client_asn"] = client_asn
end

if(server_asn ~= nil) then
   page_params["server_asn"] = server_asn
end

if(flowhosts_type ~= nil) then
  page_params["flowhosts_type"] = flowhosts_type
  flowhosts_type_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

print(getPageUrl(ntop.getHttpPrefix().."/lua/get_flows_data.lua", page_params))

print ('";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")
-- Set the flow table option

if(ifstats.vlan) then print ('flow_rows_option["vlan"] = true;\n') end

   print [[
	 var table = $("#table-flows").datatable({
			url: url_update ,
         rowCallback: function(row) { return flow_table_setID(row); },
         tableCallback: function()  { $("#dt-bottom-details > .pull-left > p").first().append('. ]]
   print(i18n('flows_page.idle_flows_not_listed'))
   print[['); },
]]
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

local filter_msg = (application or category or vhost or firstToUpper(flow_status or ""))
local active_msg

if not interface.isPacketInterface() then
   active_msg = i18n("flows_page.recently_active_flows", {filter=filter_msg})
elseif interface.isPcapDumpInterface() then
   active_msg = i18n("flows_page.flows", {filter=filter_msg})
else
   active_msg = i18n("flows_page.active_flows", {filter=filter_msg})
end

if(network_name ~= nil) then
   active_msg = active_msg .. i18n("network", {network=network_name})
end

if(inIfIdx ~= nil) then
   active_msg = active_msg .. " ["..i18n("flows_page.inIfIdx").." "..inIfIdx.."]"
end

if(outIfIdx ~= nil) then
   active_msg = active_msg .. " ["..i18n("flows_page.outIfIdx").." "..outIfIdx.."]"
end

if(deviceIP ~= nil) then
   active_msg = active_msg .. " ["..i18n("flows_page.device_ip").." "..deviceIP.."]"
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
local flowhosts_type_params = table.clone(page_params)
flowhosts_type_params["flowhosts_type"] = nil

local function printDropdownEntries(entries, param_arr, param_filter, curr_filter)
   for _, htype in ipairs(entries) do
      param_arr[param_filter] = htype[1]
      print[[<li]]

      if htype[1] == curr_filter then print(' class="active"') end

      print[[><a href="]] print(getPageUrl(base_url, param_arr)) print[[">]] print(htype[2]) print[[</a></li>]]
   end
end
print[['\
   <div class="btn-group">\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.hosts")) print(flowhosts_type_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a href="]] print(getPageUrl(base_url, flowhosts_type_params)) print[[">]] print(i18n("flows_page.all_hosts")) print[[</a></li>\]]
   printDropdownEntries({
      {"local_only", i18n("flows_page.local_only")},
      {"remote_only", i18n("flows_page.remote_only")},
      {"local_origin_remote_target", i18n("flows_page.local_cli_remote_srv")},
      {"remote_origin_local_target", i18n("flows_page.local_srv_remote_cli")}
   }, flowhosts_type_params, "flowhosts_type", flowhosts_type)
print[[\
      </ul>\
   </div>\
']]

-- Status selector
local flow_status_params = table.clone(page_params)
flow_status_params["flow_status"] = nil

print[[, '\
   <div class="btn-group">\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("status")) print(flow_status_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu">\
      <li><a href="]] print(getPageUrl(base_url, flow_status_params)) print[[">]] print(i18n("flows_page.all_flows")) print[[</a></li>\]]

   local entries = {
      {"normal", i18n("flows_page.normal")},
      {"alerted", i18n("flows_page.alerted")},
   }

   if isBridgeInterface(ifstats) then
      entries[#entries + 1] = {"filtered", i18n("flows_page.blocked")}
   end
 
   printDropdownEntries(entries, flow_status_params, "flow_status", flow_status)
print[[\
      </ul>\
   </div>\
']]

-- Unidirectional flows selector
local traffic_type_params = table.clone(page_params)
traffic_type_params["traffic_type"] = nil

print[[, '\
   <div class="btn-group">\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.direction")) print(traffic_type_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu">\
         <li><a href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("flows_page.all_flows")) print[[</a></li>\]]
printDropdownEntries({
      {"unicast", i18n("flows_page.non_multicast")},
      {"broadcast_multicast", i18n("flows_page.multicast")},
      {"one_way_unicast", i18n("flows_page.one_way_non_multicast")},
      {"one_way_broadcast_multicast", i18n("flows_page.one_way_multicast")},
   }, traffic_type_params, "traffic_type", traffic_type)
print[[\
      </ul>\
   </div>\
']]

if not category then
   -- L7 Application
   print(', \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..i18n("report.applications")..' ' .. application_filter .. '<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" id="flow_dropdown">')
   print('<li><a href="')
   local application_filter_params = table.clone(page_params)
   application_filter_params["application"] = nil
   print(getPageUrl(base_url, application_filter_params))
   print('">'..i18n("flows_page.all_proto")..'</a></li>')

   for key, value in pairsByKeys(ndpistats["ndpi"], asc) do
      local class_active = ''
      if(key == application) then
	 class_active = ' class="active"'
      end
      print('<li '..class_active..'><a href="')
      application_filter_params["application"] = key
      print(getPageUrl(base_url, application_filter_params))
      print('">'..key..'</a></li>')
   end

   print("</ul> </div>'")

end

if not application then
   -- L7 Application Category
   print(', \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..i18n("users.categories")..' ' .. category_filter .. '<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" id="flow_dropdown">')
   print('<li><a href="')
   local category_filter_params = table.clone(page_params)
   category_filter_params["category"] = nil
   print(getPageUrl(base_url, category_filter_params))
   print('">'..i18n("flows_page.all_categories")..'</a></li>')

   for key, value in pairsByKeys(ndpicatstats, asc) do
      local class_active = ''
      if(key == category) then
	 class_active = ' class="active"'
      end
      print('<li '..class_active..'><a href="')
      category_filter_params["category"] = key
      print(getPageUrl(base_url, category_filter_params))
      print('">'..key..'</a></li>')
   end

   print("</ul> </div>'")

end

-- Ip version selector
local ipversion_params = table.clone(page_params)
ipversion_params["version"] = nil

print[[, '<div class="btn-group pull-right">]]
printIpVersionDropdown(base_url, ipversion_params)
print [[</div>']]

-- VLAN selector
local vlan_params = table.clone(page_params)
if ifstats.vlan then
   print[[, '<div class="btn-group pull-right">]]
   printVLANFilterDropdown(base_url, vlan_params)
   print[[</div>']]
end

if ntop.isPro() and interface.isPacketInterface() == false then
   printFlowDevicesFilterDropdown(base_url, vlan_params)
end

-- end buttons

print(" ],\n")

print[[
   columns: [
      {
         title: "]] print(i18n("key")) print[[",
         field: "key",
         hidden: true,
         css: {
              textAlign: 'center'
         }
      }, {
         title: "",
         field: "column_key",
         css: {
            textAlign: 'center'
         }
      }, {
         title: "]] print(i18n("application")) print[[",
         field: "column_ndpi",
         sortable: true,
         css: {
            textAlign: 'center'
         }
      }, {
         title: "]] print(i18n("db_explorer.l4_proto")) print[[",
         field: "column_proto_l4",
         sortable: true,
         css: {
            textAlign: 'center'
         }
      },
]]

if(ifstats.vlan) then
   print [[
      {
        title: "]] print(i18n("vlan")) print[[",
        field: "column_vlan",
        sortable: true,
        css: {
           textAlign: 'center'
        }
      },
   ]]
end
end

print[[
      {
         title: "]] print(i18n("client")) print[[",
         field: "column_client",
         sortable: true,
      }, {
         title: "]] print(i18n("server")) print[[",
         field: "column_server",
         sortable: true,
      }, {
         title: "]] print(i18n("duration")) print[[",
         field: "column_duration",
         sortable: true,
         css: {
           textAlign: 'center'
         }
      }, {
         title: "]] print(i18n("breakdown")) print[[",
         field: "column_breakdown",
         sortable: false,
            css: {
               textAlign: 'center'
            }
      }, {
         title: "]] print(i18n("flows_page.actual_throughput")) print[[",
         field: "column_thpt",
         sortable: true,
         css: {
            textAlign: 'right'
         }
      }, {
         title: "]] print(i18n("flows_page.total_bytes")) print[[",
         field: "column_bytes",
         sortable: true,
            css: {
               textAlign: 'right'
            }
      }, {
         title: "]] print(i18n("info")) print[[",
         field: "column_info",
         sortable: true,
            css: {
               textAlign: 'left'
            }
         }
      ]
   });
</script>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
