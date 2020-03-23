--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local if_stats = interface.getStats()

if (if_stats.has_seen_pods or if_stats.has_seen_containers) then
   -- Use a different flows page
   dofile(dirs.installdir .. "/scripts/lua/inc/ebpf_flows_stats.lua")
   return
end

require "lua_utils"
require "graph_utils"
require "flow_utils"

local page_utils = require("page_utils")
local tcp_flow_state_utils = require("tcp_flow_state_utils")
local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')
page_utils.manage_system_interface()

page_utils.set_active_menu_entry(ternary(have_nedge, page_utils.menu_entries.nedge_flows, page_utils.menu_entries.flows))

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- nDPI application and category
local application = _GET["application"]
local category = _GET["category"]

local hosts = _GET["hosts"]
local host = _GET["host"]
local vhost = _GET["vhost"]
local flowhosts_type = _GET["flowhosts_type"]
local ipversion = _GET["version"]
local l4proto = _GET["l4proto"]
local vlan = _GET["vlan"]
local icmp_type = _GET["icmp_type"]
local icmp_code = _GET["icmp_cod"]
local traffic_profile = _GET["traffic_profile"]

-- remote exporters address and interfaces
local deviceIP = _GET["deviceIP"]
local inIfIdx  = _GET["inIfIdx"]
local outIfIdx = _GET["outIfIdx"]

local traffic_type = _GET["traffic_type"]
local flow_status = _GET["flow_status"]
local tcp_state   = _GET["tcp_flow_state"]
local port = _GET["port"]

local network_id = _GET["network"]

local client_asn = _GET["client_asn"]
local server_asn = _GET["server_asn"]

local prefs = ntop.getPrefs()
local ifstats = interface.getStats()

local flows_filter = getFlowsFilter()

flows_filter.statusFilter = nil -- remove the filter, otherwise no menu entries will be shown
local flowstats = interface.getActiveFlowsStats(host, flows_filter)

local base_url = ntop.getHttpPrefix() .. "/lua/flows_stats.lua"
local page_params = {}

if (page == "flows" or page == nil) then

print [[
      <div id="table-flows"></div>]]

print(i18n("notes"))
print[[<ul>
  <li>]]
print(i18n("flows_page.misbehaving_flows_node",
    {url = "https://www.ntop.org/guides/ntopng/basic_concepts/alerts.html#misbehaving-flows"}))
print[[</li>
</ul>]]

print[[
	 <script>
   var url_update = "]]

if(category ~= nil) then
   page_params["category"] = category
end

if(application ~= nil) then
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

if(flow_status ~= nil) then
   page_params["flow_status"] = flow_status
end

if(tcp_state ~= nil) then
   page_params["tcp_flow_state"] = tcp_state
end

if(network_id ~= nil) then
  page_params["network"] = network_id
end

if(flowhosts_type ~= nil) then
  page_params["flowhosts_type"] = flowhosts_type
end

if((icmp_type ~= nil) and (icmp_code ~= nil)) then
  page_params["icmp_type"] = icmp_type
  page_params["icmp_cod"] = icmp_code
end

if(traffic_profile ~= nil) then
  page_params["traffic_profile"] = traffic_profile
end

print(getPageUrl(ntop.getHttpPrefix().."/lua/get_flows_data.lua", page_params))

print ('";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")
-- Set the flow table option

if(ifstats.vlan) then print ('flow_rows_option["vlan"] = true;\n') end
--if(ifstats.has_seen_ebpf_events) then print ('flow_rows_option["process"] = true;\n') end

   print [[
	 var table = $("#table-flows").datatable({
			url: url_update ,
         rowCallback: function(row) { return flow_table_setID(row); },
         tableCallback: function()  { $("#dt-bottom-details > .float-left > p").first().append('. ]]
   print(i18n('flows_page.idle_flows_not_listed'))
   print[['); },
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

printActiveFlowsDropdown(base_url, page_params, ifstats, flowstats)

print(" ],\n")

print[[
   columns: [
      {
         title: "",
         field: "key",
         hidden: true,
      }, {
         title: "",
         field: "hash_id",
         hidden: true,
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
         title: "]] print(i18n("duration")) print[[",
         field: "column_duration",
         sortable: true,
         css: {
            textAlign: 'center'
         }
      }, {
         title: "]] print(i18n("score")) print[[",
         field: "column_score",
         hidden: ]] print(ternary(isScoreEnabled(), "false", "true")) print[[,
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
