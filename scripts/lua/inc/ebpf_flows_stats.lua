--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
require "flow_utils"

local page_utils = require("page_utils")
local tcp_flow_state_utils = require("tcp_flow_state_utils")
local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.flows)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- nDPI application and category
local application = _GET["application"]
local category = _GET["category"]

local hosts = _GET["hosts"]
local host = _GET["host"]
local vhost = _GET["vhost"]
local flowhosts_type = _GET["flowhosts_type"]
local ipversion = _GET["version"]
local vlan = _GET["vlan"]
local l4proto = _GET["l4proto"]

-- remote exporters address and interfaces
local deviceIP = _GET["deviceIP"]
local inIfIdx  = _GET["inIfIdx"]
local outIfIdx = _GET["outIfIdx"]

local traffic_type = _GET["traffic_type"]
local alert_type = _GET["alert_type"]
local tcp_state   = _GET["tcp_flow_state"]
local port = _GET["port"]
local container = _GET["container"]
local pod = _GET["pod"]

local network_id = _GET["network"]

local client_asn = _GET["client_asn"]
local server_asn = _GET["server_asn"]

local prefs = ntop.getPrefs()
interface.select(ifname)
local ifstats = interface.getStats()
local ndpistats = interface.getActiveFlowsStats()

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
elseif(application ~= nil) then
   page_params["application"] = application
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
end

if(l4proto ~= nil) then
  page_params["l4proto"] = l4proto
end

if(deviceIP ~= nil) then
   page_params["deviceIP"] = deviceIP
end

if(inIfIdx ~= nil) then
   page_params["inIfIdx"] = inIfIdx
end

if(outIfIdx ~= nil) then
   page_params["outIfIdx"] = outIfIdx
end

if(vlan ~= nil) then
  page_params["vlan"] = vlan
end

if(traffic_type ~= nil) then
   page_params["traffic_type"] = traffic_type
end

if(alert_type ~= nil) then
   page_params["alert_type"] = alert_type
end

if(tcp_state ~= nil) then
   page_params["tcp_flow_state"] = tcp_state
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
end

if(pod ~= nil) then
  page_params["pod"] = pod
end

if(container ~= nil) then
  page_params["container"] = container
end

print(getPageUrl(ntop.getHttpPrefix().."/lua/get_flows_data.lua", page_params))

print ('";')

   print [[
	 var table = $("#table-flows").datatable({
			url: url_update ,]]
   print[[
         tableCallback: function()  {
            ]] initFlowsRefreshRows() print[[
         },
]]
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

local active_msg = getFlowsTableTitle()

print(" title: \""..active_msg)


print [[",
         showFilter: true,
         showPagination: true,
]]

-- Automatic default sorted. NB: the column must be exists.
print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')

print ('buttons: [')

printActiveFlowsDropdown(base_url, page_params, ifstats, ndpistats, true --[[ ebpf_flows ]])

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
         title: "]] print(i18n("protocol")) print[[",
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
         title: "]] print(i18n("containers_stats.client_rtt")) print[[",
         field: "column_client_rtt",
         sortable: true,
            css: {
               textAlign: 'right'
            }
      }, {
         title: "]] print(i18n("containers_stats.server_rtt")) print[[",
         field: "column_server_rtt",
         sortable: true,
            css: {
               textAlign: 'right'
            }
      }, {
         title: "]] print(i18n("info")) print[[",
         field: "column_info",
         sortable: false,
            css: {
               textAlign: 'left'
            }
         }
      ]
   });
]]

if(have_nedge) then
  printBlockFlowJs()
end

print[[
</script>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
