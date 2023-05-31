--
-- (C) 2013-23 - ntop.org
--
-- trace_script_duration = true
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local if_stats = interface.getStats()

if (if_stats.has_seen_pods or if_stats.has_seen_containers) then
    -- Use a different flows page
    dofile(dirs.installdir .. "/scripts/lua/inc/ebpf_flows_stats.lua")
    return
end

require "lua_utils"
require "flow_utils"

local page_utils = require("page_utils")
local template = require "template_utils"
local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(ternary(have_nedge, page_utils.menu_entries.nedge_flows,
    page_utils.menu_entries.active_flows))

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- nDPI application and category
local application = _GET["application"]

if (application ~= nil) then
    local application_split = string.split(application, "%.")

    if application_split and #application_split == 2 then
        -- 5.26
    else
        local _application = tonumber(application)

        if (_application) then
            application = interface.getnDPIProtoName(_application)
        end
    end
end

local category = _GET["category"]
local hosts = _GET["hosts"]
local host = _GET["host"]
local talking_with = _GET["talkingWith"]
local client = _GET["client"]
local server = _GET["server"]
local flow_info = _GET["flow_info"]
local vhost = _GET["vhost"]
local flowhosts_type = _GET["flowhosts_type"]
local ipversion = _GET["version"]
local l4proto = _GET["l4proto"]
local vlan = _GET["vlan"]
local icmp_type = _GET["icmp_type"]
local icmp_code = _GET["icmp_cod"]
local dscp_filter = _GET["dscp"]
local host_pool = _GET["host_pool_id"]
local traffic_profile = _GET["traffic_profile"]

local aggregation_criteria = _GET["aggregation_criteria"] or "application_protocol"

local draw = _GET["draw"] or 0
local sort = _GET["sort"] or "bytes_rcvd"
local order = _GET["order"] or "asc"
local start = _GET["start"] or 0
local length = _GET["length"] or 10

-- remote exporters address and interfaces
local deviceIP = _GET["deviceIP"]
local inIfIdx = _GET["inIfIdx"]
local outIfIdx = _GET["outIfIdx"]

local traffic_type = _GET["traffic_type"]
local alert_type = _GET["alert_type"]
local alert_type_severity = _GET["alert_type_severity"]
local tcp_state = _GET["tcp_flow_state"]
local port = _GET["port"]
local network_id = _GET["network"]
local page = _GET["page"]

local prefs = ntop.getPrefs()
local ifstats = interface.getStats()

local duration_or_last_seen = prefs.flow_table_time
local begin_epoch_set = (ntop.getPref("ntopng.prefs.first_seen_set") == "1")

local flows_filter = getFlowsFilter()

flows_filter.statusFilter = nil -- remove the filter, otherwise no menu entries will be shown
local flowstats = interface.getActiveFlowsStats(host, flows_filter, false, talking_with, client, server, flow_info)
local base_url = ntop.getHttpPrefix() .. "/lua/flows_stats.lua"
local page_params = {
    ifid = interface.getId(),
    client = client,
    server = server,
    flow_info = flow_info
}
local mini_title = i18n("flow_details.purge_time", {
    purge_time = ntop.getPref("ntopng.prefs.flow_max_idle"),
    prefs_url = ntop.getHttpPrefix() .. '/lua/admin/prefs.lua?tab=in_memory'
})

page_utils.print_navbar(i18n('graphs.active_flows'), base_url .. "?", {{
    active = page == "flows" or page == nil,
    page_name = "flows",
    label = "<i class=\"fas fa-lg fa-home\"></i>"
}, {
    url = base_url .. "?page=analysis&aggregation_criteria=" .. aggregation_criteria .. "&draw=" .. draw .. "&sort=" ..
        sort .. "&order=" .. order .. "&start=" .. start .. "&length=" .. length,
    active = page == "analysis",
    page_name = "analysis",
    label = i18n("analysis")
}})

if (page == "flows" or page == nil) then
    local active_msg = getFlowsTableTitle(ntop.getHttpPrefix())
    if (category ~= nil) then
        page_params["category"] = category
    end

    if (application ~= nil) then
        page_params["application"] = application
    end

    if (host ~= nil) then
        page_params["host"] = host
    end

    if (port ~= nil) then
        page_params["port"] = port
    end

    if (vhost ~= nil) then
        page_params["vhost"] = vhost
    end

    if (hosts ~= nil) then
        page_params["hosts"] = hosts
    end

    if (port ~= nil) then
        page_params["port"] = port
    end

    if (ipversion ~= nil) then
        page_params["version"] = ipversion
    end

    if (l4proto ~= nil) then
        page_params["l4proto"] = l4proto
    end

    if (deviceIP ~= nil) then
        page_params["deviceIP"] = deviceIP
    end

    if (inIfIdx ~= nil) then
        page_params["inIfIdx"] = inIfIdx
    end

    if (outIfIdx ~= nil) then
        page_params["outIfIdx"] = outIfIdx
    end

    if (vlan ~= nil) then
        page_params["vlan"] = vlan
    end

    if (traffic_type ~= nil) then
        page_params["traffic_type"] = traffic_type
    end

    if (alert_type ~= nil) then
        page_params["alert_type"] = alert_type
    end

    if (alert_type_severity ~= nil) then
        page_params["alert_type_severity"] = alert_type_severity
    end

    if (tcp_state ~= nil) then
        page_params["tcp_flow_state"] = tcp_state
    end

    if (network_id ~= nil) then
        page_params["network"] = network_id
    end

    if (flowhosts_type ~= nil) then
        page_params["flowhosts_type"] = flowhosts_type
    end

    if ((icmp_type ~= nil) and (icmp_code ~= nil)) then
        page_params["icmp_type"] = icmp_type
        page_params["icmp_cod"] = icmp_code
    end

    if (dscp_filter ~= nil) then
        page_params["dscp"] = dscp_filter
    end

    if (host_pool ~= nil) then
        page_params["host_pool_id"] = host_pool
    end

    if (traffic_profile ~= nil) then
        page_params["traffic_profile"] = traffic_profile
    end
    local is_chart_printed = false

    print [[<div class="d-flex m-1">]]

    if is_chart_printed then
        print [[<h3 class="m-auto">]]
    else
        print [[<h3 class="me-auto mt-auto mb-auto">]]
    end

    print(active_msg)
    print [[</h3>]]

    if (table.len(page_params) > 0) and (not isEmptyString(page_params["application"])) then
        is_chart_printed = true
        print [[
         <div class="col-5">
            <div class="info-stats">
               <ul class="nav-side m-0 ps-5 ms-1" style="list-style-type: none;">
                  <li class="nav-item">
                     <div class="up">
                        <i class="fas fa-arrow-up" data-original-title="" title=""></i>
                        <span id="upload-filter-traffic-chart" class="line">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>
                        <span class='d-inline-block text-end' style='width: 13ch'>
                           <span id="upload-filter-traffic-value">0 kbit/s</span> |
                        </span>
                        <span id="filtered-flows-tot-bytes">]]
        print(i18n("flows_page.tot_bytes"))
        print [[</span>
                        <span id="filtered-flows-tot-bytes-value">0 B</span>
                     </div>
                  </li>
                  <li class="nav-item">
                     <div class="down">
                        <i class="fas fa-arrow-down" data-original-title="" title=""></i>
                        <span id="download-filter-traffic-chart" class="line">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>
                        <span class='d-inline-block text-end' style='width: 13ch'>
                           <span id="download-filter-traffic-value">0 kbit/s</span> |
                        </span>
                        <span id="filtered-flows-tot-throughput">]]
        print(i18n("flows_page.tot_throughput"))
        print [[</span>
                        <span id="filtered-flows-tot-throughput-value">0 kbit/s</span>
                     </div>
                  </li>
               </ul>
            </div>
         </div>
   ]]
    end

    print [[<h6 class="ms-auto mt-auto mb-auto">]]
    print(mini_title)
    print [[</h6>]]
    print [[</div>]]

    print [[
         <div id="table-flows"></div>
           <script>
      var url_update = "]]
    print(getPageUrl(ntop.getHttpPrefix() .. "/lua/get_flows_data.lua", page_params))

    print('";')

    print [[
   
   	 var table = $("#table-flows").datatable({
   			url: url_update ,
            tableCallback: function(test_tmp)  {
               ]]
    initFlowsRefreshRows()
    print [[
            },
   ]]

    preference = tablePreferences("rows_number", _GET["perPage"])
    if (preference ~= "") then
        print('perPage: ' .. preference .. ",\n")
    end

    print(" title: \"")

    print [[",
            showFilter: true,
            showPagination: true,
   ]]

    -- Automatic default sorted. NB: the column must be exists.
    print('sort: [ ["' .. getDefaultTableSort("flows") .. '","' .. getDefaultTableSortOrder("flows") .. '"] ],\n')

    print('buttons: [')

    printActiveFlowsDropdown(base_url, page_params, ifstats, flowstats)

    print(" ],\n")

    print [[
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
            title: "]]
    print(i18n("serial"))
    print [[",
            field: "column_key", /* This is the serial numebe but called key for placing the flow button pointing to the flow key */
            sortable: false,
            css: {
               textAlign: 'center',
               whiteSpace: 'nowrap'

            }
         }, {
            title: "]]
    print(i18n("application"))
    print [[",
            field: "column_ndpi",
            sortable: true,
            css: {
               textAlign: 'left',
               whiteSpace: 'nowrap'
            }
         }, {
            title: "]]
    print(i18n("proto"))
    print [[",
            field: "column_proto_l4",
            sortable: true,
            css: {
               textAlign: 'left',
               whiteSpace: 'nowrap'
            }
         },
   ]]

    print [[
         {
            title: "]]
    print(i18n("client"))
    print [[",
            field: "column_client",
            sortable: true,
            css: {
               whiteSpace: 'nowrap'
            }
         }, {
            title: "]]
    print(i18n("server"))
    print [[",
            field: "column_server",
            sortable: true,
            css: {
               whiteSpace: 'nowrap'
            }
   
         },
   ]]

    if begin_epoch_set == true then
        print [[
         {
            title: "]]
        print(i18n("first_seen"))
        print [[",
            field: "column_first_seen",
            sortable: true,
            css: {
               whiteSpace: 'nowrap',
               textAlign: 'center',
            }
         },
      ]]
    end

    if duration_or_last_seen == false then
        print [[
         {
            title: "]]
        print(i18n("duration"))
        print [[",
            field: "column_duration",
            sortable: true,
            css: {
               whiteSpace: 'nowrap',
               textAlign: 'center',
            }
         },
      ]]
    else
        print [[
         {
            title: "]]
        print(i18n("last_seen"))
        print [[",
            field: "column_last_seen",
            sortable: true,
            css: {
               whiteSpace: 'nowrap',
               textAlign: 'center'
            }
         },
      ]]
    end

    print [[{
            title: "]]
    print(i18n("score"))
    print [[",
            field: "column_score",
            hidden: ]]
    print(ternary(isScoreEnabled(), "false", "true"))
    print [[,
            sortable: true,
            css: {
               textAlign: 'center',
               whiteSpace: 'nowrap'
            }
         }, {
            title: "]]
    print(i18n("breakdown"))
    print [[",
            field: "column_breakdown",
            sortable: false,
            css: {
               textAlign: 'center',
               whiteSpace: 'nowrap'
            }
         }, {
            title: "]]
    print(i18n("flows_page.actual_throughput"))
    print [[",
            field: "column_thpt",
            sortable: true,
            css: {
               textAlign: 'right',
               whiteSpace: 'nowrap'
            }
         }, {
            title: "]]
    print(i18n("flows_page.total_bytes"))
    print [[",
            field: "column_bytes",
            sortable: true,
            css: {
               textAlign: 'right',
               whiteSpace: 'nowrap'
            }
         }, {
            title: "]]
    print(i18n("info"))
    print [[",
            field: "column_info",
            sortable: false,
            css: {
               textAlign: 'left',
               whiteSpace: 'nowrap'
            }
         },]]
    if interface.isPacketInterface() == false then
        print [[
         {
            title: "]]
        print(i18n('flow_devices.exporter_ip'))
        print [[",
            field: "column_device_ip",
            sortable: true,
            css: {
               textAlign: 'left',
               whiteSpace: 'nowrap'
            }
         }, {
            title: "]]
        print(i18n('flows_page.inIfIdx'))
        print [[",
            field: "column_in_index",
            sortable: true,
            css: {
               textAlign: 'left',
               whiteSpace: 'nowrap'
            }
         }, {
            title: "]]
        print(i18n('flows_page.outIfIdx'))
        print [[",
            field: "column_out_index",
            sortable: true,
            css: {
               textAlign: 'left',
               whiteSpace: 'nowrap'
            }
         },
      ]]
    end
    print [[
         ]
      });
   ]]

    if (have_nedge) then
        printBlockFlowJs()
    end
    print [[
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
   
                  const request = $.get("]] ..
                  getPageUrl(ntop.getHttpPrefix() .. "/lua/rest/v2/get/flow/traffic_stats.lua", page_params) .. "&ifid=" ..
                  interface.getId() .. [[");
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
else
    -- Analysis

    local json = require 'dkjson'
    -- Format VLANs dropdown
    local tmp_vlans = {}
    local vlans = {}
    local vlan_list = interface.getVLANsList() or {}

    if table.len(vlan_list) > 0 then
        vlan_list = vlan_list.VLANs
    end

    for _, vlan_info in pairsByField(vlan_list or {}, 'vlan_id', asc) do
        local label = i18n("hosts_stats.vlan_title", {
            vlan = getFullVlanName(vlan_info.vlan_id)
        })
        local currently_active = false

        if vlan_info.vlan_id == 0 then
            label = i18n('no_vlan')
        end

        tmp_vlans[#tmp_vlans + 1] = {
            label = label,
            id = vlan_info.vlan_id,
            countable = false,
            key = vlan_info.vlan_id,
            currently_active = (vlan == vlan_info.vlan_id or currently_active)
        }
    end
    if (#tmp_vlans > 1) then
        local currently_active = false

        tmp_vlans[#tmp_vlans + 1] = {
            label = i18n("flows_page.all_vlan_ids"),
            id = -1,
            countable = false,
            key = -1,
            currently_active = (vlan == -1 or currently_active)
        }
    end

    -- Order again by name
    for _, vlan in pairsByField(tmp_vlans or {}, 'label', asc_insensitive) do
        vlans[#vlans + 1] = vlan
    end

    template.render("pages/aggregated_live_flows.template", {
        ifid = ifId,
        vlans = json.encode(vlans),
        aggregation_criteria = aggregation_criteria,
        draw = draw,
        sort = sort,
        order = order,
        start = start,
        length = length,
        host = ""
    })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
