--
-- (C) 2013-21 - ntop.org
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
local graph_utils = require "graph_utils"
require "flow_utils"

local page_utils = require("page_utils")
local tcp_flow_state_utils = require("tcp_flow_state_utils")
local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')

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
local port = _GET["port"]
local icmp_type = _GET["icmp_type"]
local icmp_code = _GET["icmp_cod"]
local dscp_filter = _GET["dscp"]
local host_pool = _GET["host_pool_id"]
local traffic_profile = _GET["traffic_profile"]

-- remote exporters address and interfaces
local deviceIP = _GET["deviceIP"]
local inIfIdx  = _GET["inIfIdx"]
local outIfIdx = _GET["outIfIdx"]

local traffic_type = _GET["traffic_type"]
local alert_type  = _GET["alert_type"]
local alert_type_severity  = _GET["alert_type_severity"]
local tcp_state    = _GET["tcp_flow_state"]
local port         = _GET["port"]
local network_id   = _GET["network"]
local client_asn   = _GET["client_asn"]
local server_asn   = _GET["server_asn"]

local prefs = ntop.getPrefs()
local ifstats = interface.getStats()

local duration_or_last_seen = prefs.flow_table_time

local flows_filter = getFlowsFilter()

flows_filter.statusFilter = nil -- remove the filter, otherwise no menu entries will be shown
local flowstats = interface.getActiveFlowsStats(host, flows_filter)

local base_url = ntop.getHttpPrefix() .. "/lua/flows_stats.lua"
local page_params = {}

if (page == "flows" or page == nil) then
   local active_msg = getFlowsTableTitle()

   page_utils.print_page_title(active_msg)


if(category ~= nil) then
   page_params["category"] = category
end

if(application ~= nil) then
   page_params["application"] = application
end

if(host ~= nil) then
  page_params["host"] = host
end

if(port ~= nil) then
  page_params["port"] = port
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

if(alert_type_severity ~= nil) then
   page_params["alert_type_severity"] = alert_type_severity
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

if(dscp_filter ~= nil) then
   page_params["dscp"] = dscp_filter
end

if(host_pool ~= nil) then
   page_params["host_pool_id"] = host_pool
end

if(traffic_profile ~= nil) then
  page_params["traffic_profile"] = traffic_profile
end

if (table.len(page_params) > 0) and (not isEmptyString(page_params["application"])) then
      print [[
      <div class="col-12 p-1">
         <div class="info-stats">
            <a href="#">
               <div class="up">
                  <i class="fas fa-arrow-up" data-original-title="" title=""></i>
                  <span id="upload-filter-traffic-chart" class="line">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>
                  <div class='d-inline-block text-end' style='width: 11ch'>
                     <span id="upload-filter-traffic-value">0 kbit/s</span> |
                  </div>
                  <span id="filtered-flows-tot-bytes">]] print(i18n("flows_page.tot_bytes")) print[[</span>
                  <span id="filtered-flows-tot-bytes-value">0 B</span>
               </div>
               <div class="down">
                  <i class="fas fa-arrow-down" data-original-title="" title=""></i>
                  <span id="download-filter-traffic-chart" class="line">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>
                  <div class='d-inline-block text-end' style='width: 11ch'>
                     <span id="download-filter-traffic-value">0 kbit/s</span> |
                  </div>
                  <span id="filtered-flows-tot-throughput">]] print(i18n("flows_page.tot_throughput")) print[[</span>
                  <span id="filtered-flows-tot-throughput-value">0 kbit/s</span>
               </div>
            </a>
         </div>
      </div>
]]
end

   print [[
      <div id="table-flows"></div>
        <script>
   var url_update = "]]

print(getPageUrl(ntop.getHttpPrefix().."/lua/get_flows_data.lua", page_params))

print ('";')

   print [[

	 var table = $("#table-flows").datatable({
			url: url_update ,
         tableCallback: function(test_tmp)  {
            ]] initFlowsRefreshRows() print[[
         },
]]

preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

print(" title: \"")


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
            textAlign: 'center',
            whiteSpace: 'nowrap'
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
         css: {
            whiteSpace: 'nowrap'
         }
      }, {
         title: "]] print(i18n("server")) print[[",
         field: "column_server",
         sortable: true,
         css: {
            whiteSpace: 'nowrap'
         }

      }, ]]

if duration_or_last_seen == false then 
   print[[
      {
         title: "]] print(i18n("duration")) print[[",
         field: "column_duration",
         sortable: true,
         css: {
            textAlign: 'center',
         }
      },
   ]]
else
   print[[
      {
         title: "]] print(i18n("last_seen")) print[[",
         field: "column_last_seen",
         sortable: true,
         css: {
            textAlign: 'center'
         }
      },
   ]]
end   
print[[{
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
            textAlign: 'right',
            whiteSpace: 'nowrap'
         }
      }, {
         title: "]] print(i18n("flows_page.total_bytes")) print[[",
         field: "column_bytes",
         sortable: true,
         css: {
            textAlign: 'right',
            whiteSpace: 'nowrap'
         }
      }, {
         title: "]] print(i18n("info")) print[[",
         field: "column_info",
         sortable: false,
         css: {
            textAlign: 'left',
            whiteSpace: 'nowrap'
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

if (table.len(page_params) > 0) and (not isEmptyString(page_params["application"])) then
   print([[
      <script type='text/javascript'>
         let old_totBytesSent = 0;
         let old_totBytesRcvd = 0;
         let refresh_rate     = 5; /* seconds */

         $(document).ready(function() {
            const downloadChart = $("#download-filter-traffic-chart").peity("line", { width: 64, fill: "lightgreen" });
            const uploadChart = $("#upload-filter-traffic-chart").peity("line", { width: 64 });
            
            function pushNewValue(chart, newValue) {
               const values = chart.text().split(",");
               values.shift();
               values.push(newValue);

               chart
                 .text(values.join(","))
                 .change()
            }

            function updateChart() {

               const request = $.get("]] .. getPageUrl(ntop.getHttpPrefix() .. "/lua/rest/v2/get/flow/traffic_stats.lua", page_params) .. "&ifid=" .. interface.getId() .. [[");
               request.then((data) => {
                  let throughput_bps_sent = (8 * (data.rsp.totBytesSent - old_totBytesSent)) / refresh_rate;
                  let throughput_bps_rcvd = (8 * (data.rsp.totBytesRcvd - old_totBytesRcvd)) / refresh_rate;
                  let tot_throughput = (8 * data.rsp.totThpt);

                  if (tot_throughput < 0)      tot_throughput = 0;
                  if (throughput_bps_sent < 0) throughput_bps_sent = 0;
                  if (throughput_bps_rcvd < 0) throughput_bps_rcvd = 0;

                  if ((old_totBytesSent > 0) || (old_totBytesRcvd > 0)) {
                    /* Second iteration or later */
                    pushNewValue(downloadChart, -throughput_bps_rcvd);
                    pushNewValue(uploadChart, throughput_bps_sent);
                    $('#download-filter-traffic-value').html(NtopUtils.bitsToSize(throughput_bps_rcvd, 1000));                  
                    $('#upload-filter-traffic-value').html(NtopUtils.bitsToSize(throughput_bps_sent, 1000));
                  }

                  /* Keep the old value for computing the differnce at the next round */
                  old_totBytesSent = data.rsp.totBytesSent;
                  old_totBytesRcvd = data.rsp.totBytesRcvd;
                  $('#filtered-flows-tot-bytes-value').html(NtopUtils.bytesToSize(old_totBytesSent + old_totBytesRcvd));
                  $('#filtered-flows-tot-throughput-value').html(NtopUtils.bitsToSize(tot_throughput, 1000));
               })
            }

            setInterval(() => { updateChart() }, refresh_rate*1000);

            updateChart();
         })
      </script>
   ]])
end


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
