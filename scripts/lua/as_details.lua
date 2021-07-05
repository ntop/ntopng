--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    local snmp_utils = require "snmp_utils"
end

require "lua_utils"
local graph_utils = require "graph_utils"
local ts_utils = require("ts_utils")
local page_utils = require("page_utils")

local asn            = tonumber(_GET["asn"])
local page           = _GET["page"]

local application    = _GET["application"]
local version     = _GET["version"]
local flowhosts_type = _GET["flowhosts_type"]

interface.select(ifname)

local as_info = interface.getASInfo(asn) or {}
local ifId = getInterfaceId(ifname)
local asname = as_info["asname"]
local base_url = ntop.getHttpPrefix() .. "/lua/as_details.lua"
local asn_behavior_update_freq = 300 -- An update each 300 seconds

local page_params = {}

if asn then
   page_params["asn"] = asn
end

if asn then
   page_params["application"] = application
end

if page then
   page_params["page"] = page
end

if flowhosts_type then
   page_params["flowhosts_type"] = flowhosts_type
end

local label = (asn or '')..''
if not isEmptyString(asname) then
   label = label.." ["..shortenString(asname).."]"
end

sendHTTPContentTypeHeader('text/html')

-- #######################

local function formatDropdownEntries(entries, base_url, param_arr, param_filter, curr_filter)
   local dropdownString = "" 

   for _, htype in ipairs(entries) do
      if type(htype) == "string" then
        -- plain html
        dropdownString = htype
        goto continue
      end

      param_arr[param_filter] = htype[1]
      
      dropdownString = dropdownString .. '<li><a class="dropdown-item' .. (htype[1] == curr_filter and 'active' or '') .. '" href="' .. getPageUrl(base_url, param_arr) .. '">' .. htype[2] .. '</a></li>'
      ::continue::
   end

   return dropdownString
end

-- #######################

local function addDropdownEntries(entries, base_url, param_arr, param_filter, curr_filter)
   local dropdownString = "" 

   for _, htype in ipairs(entries) do
      if type(htype) == "string" then
        -- plain html
        dropdownString = htype
        goto continue
      end

      param_arr[param_filter] = htype[1]
      
      dropdownString = dropdownString .. '<li><a class="dropdown-item' .. (htype[1] == curr_filter and 'active' or '') .. '" href="' .. getPageUrl(base_url, param_arr) .. '">' .. htype[2] .. '</a></li>'
      ::continue::
   end

   return dropdownString
end

-- #######################

page_utils.print_header()
page_utils.set_active_menu_entry(page_utils.menu_entries.autonomous_systems)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if isEmptyString(asn) then
   print("<div class=\"alert alert alert-danger\">".."<i class='fas fa-exclamation-triangle fa-lg' style='color: #B94A48;'></i> " .. i18n("as_details.as_parameter_missing_message") .. "</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

--[[
   Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/as_details.lua?asn="..tonumber(asn)

local title = i18n("as_details.as") .. ": "..label

page_utils.print_navbar(title, nav_url,
			{
			   {
			      active = page == "flows" or not page,
			      page_name = "flows",
			      label = i18n("flows"),
			   },
			   {
			      active = page == "historical",
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			}
)

if isEmptyString(page) or page == "historical" then   
   local default_schema = "asn:traffic"

   if(not ts_utils.exists(default_schema, {ifid=ifId, asn=asn})) then
      print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "..i18n("as_details.no_available_data_for_as",{asn = label}))
      print(" "..i18n("as_details.as_timeseries_enable_message",{url = ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=on_disk_ts",icon_flask="<i class=\"fas fa-flask\"></i>"})..'</div>')

   else
      local schema = _GET["ts_schema"] or default_schema
      local selected_epoch = _GET["epoch"] or ""
      local asn_url = ntop.getHttpPrefix()..'/lua/as_details.lua?ifid='..ifId..'&asn='..asn..'&page=historical'

      local tags = {
         ifid = ifId,
         asn = asn,
         protocol = _GET["protocol"],
       }

       local all_timeseries = {
         {schema="asn:traffic",             label=i18n("traffic"), split_directions = true --[[ split RX and TX directions ]]},
			{schema="asn:rtt",                 label=i18n("graphs.num_ms_rtt"), nedge_exclude=1},
			{schema="asn:traffic_sent",        label=i18n("graphs.traffic_sent"), nedge_exclude=1},
			{schema="asn:traffic_rcvd",        label=i18n("graphs.traffic_rcvd"), nedge_exclude=1},
			{schema="asn:score",                 label=i18n("score"), split_directions = true},
			{schema="asn:tcp_retransmissions", label=i18n("graphs.tcp_packets_retr"), nedge_exclude=1},
         {schema="asn:tcp_out_of_order",    label=i18n("graphs.tcp_packets_ooo"), nedge_exclude=1},
         {schema="asn:tcp_lost",            label=i18n("graphs.tcp_packets_lost"), nedge_exclude=1},
         {schema="asn:tcp_keep_alive",      label=i18n("graphs.tcp_packets_keep_alive"), nedge_exclude=1},
       }

       if ntop.isPro() then
         local pro_timeseries = {
            {schema="asn:score_anomalies",       label=i18n("graphs.iface_score_anomalies")},
            {schema="asn:score_behavior",        label=i18n("graphs.iface_score_behavior"), split_directions = true, first_timeseries_only = true, metrics_labels = {i18n("graphs.score"), i18n("graphs.lower_bound"), i18n("graphs.upper_bound")}},
            {schema="asn:traffic_anomalies",     label=i18n("graphs.iface_traffic_anomalies")},
            {schema="asn:traffic_rx_behavior_v2",   label=i18n("graphs.iface_traffic_rx_behavior"), split_directions = true, first_timeseries_only = true, time_elapsed = asn_behavior_update_freq, value_formatter = {"NtopUtils.fbits_from_bytes", "NtopUtils.bytesToSize"}, metrics_labels = {i18n("graphs.traffic_rcvd"), i18n("graphs.lower_bound"), i18n("graphs.upper_bound")}},
            {schema="asn:traffic_tx_behavior_v2",   label=i18n("graphs.iface_traffic_tx_behavior"), split_directions = true, first_timeseries_only = true, time_elapsed = asn_behavior_update_freq, value_formatter = {"NtopUtils.fbits_from_bytes", "NtopUtils.bytesToSize"}, metrics_labels = {i18n("graphs.traffic_sent"), i18n("graphs.lower_bound"), i18n("graphs.upper_bound")}},
         }
         all_timeseries = table.merge(all_timeseries, pro_timeseries)
       end

       graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], asn_url, selected_epoch, {
         top_protocols = "top:asn:ndpi",
         timeseries = all_timeseries,
       })
   end

   print[[
     <br>
       <div>
         <b>]] print(i18n('notes')) print[[</b>
         <ul>
           <li>]] print(i18n('graphs.note_ases_traffic')) print[[</li>
           <li>]] print(i18n('graphs.note_ases_sent')) print[[</li>
           <li>]] print(i18n('graphs.note_ases_rcvd')) print[[</li>
         </ul>
       </div>
]]

elseif page == "flows" then
   
print [[
      <div id="table-flows"></div>
	 <script>
   var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_flows_data.lua?ifid=]]
print(ifId.."&")

if not isEmptyString(application) then
   print("application="..application.."&")
end

if not isEmptyString(flowhosts_type) then
   print("flowhosts_type="..flowhosts_type.."&")
end

if not isEmptyString(version) then
   print("version="..version.."&")
end

print("asn="..asn..'";')

local active_flows_msg = i18n("flows_page.active_flows",{filter = ""})
if not interface.isPacketInterface() then
   active_flows_msg = i18n("flows_page.recently_active_flows",{filter = ""})
elseif interface.isPcapDumpInterface() then
   active_flows_msg = i18n("flows")
end

local application_filter = ''
if(application ~= nil) then
   application_filter = '<span class="fas fa-filter"></span>'
end

local dt_buttons = "['<div class=\"btn-group\"><button class=\"btn btn-link dropdown-toggle\" data-bs-toggle=\"dropdown\">"..i18n("flows_page.applications").. " " .. application_filter .. "<span class=\"caret\"></span></button> <ul class=\"dropdown-menu\" role=\"menu\" >"
dt_buttons = dt_buttons..'<li><a class="dropdown-item" href="'..nav_url..'&page=flows">'..i18n("flows_page.all_proto")..'</a></li>'

local ndpi_stats = interface.getASInfo(asn)

for key, value in pairsByKeys(ndpi_stats["ndpi"], asc) do
   local class_active = ''
   if(key == application) then
      class_active = 'active'
   end
   dt_buttons = dt_buttons..'<li><a class="dropdown-item '..class_active..'" href="'..nav_url..'&page=flows&application='..key..'">'..key..'</a></li>'
end

dt_buttons = dt_buttons .. "</ul>"

-- Hosts type dropdown
dt_buttons = dt_buttons .. '<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">' .. i18n("flows_page.hosts") .. '<span class="caret"></span></button><ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">'

local flowhosts_type_params = table.clone(page_params)
flowhosts_type_params["flowhosts_type"] = nil

dt_buttons = dt_buttons .. formatDropdownEntries({
      {"all_hosts", i18n("flows_page.all_hosts")},
      {"local_only", i18n("flows_page.local_only")},
      {"remote_only", i18n("flows_page.remote_only")},
      {"local_origin_remote_target", i18n("flows_page.local_cli_remote_srv")},
      {"remote_origin_local_target", i18n("flows_page.local_srv_remote_cli")}
						 }, base_url, flowhosts_type_params, "flowhosts_type", page_params.flowhosts_type)

dt_buttons = dt_buttons .. "</ul>"

-- IP version dropdown
dt_buttons = dt_buttons .. '<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">' .. i18n("flows_page.ip_version") .. '<span class="caret"></span></button><ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">'

local flowhosts_type_params = table.clone(page_params)
flowhosts_type_params["ipversion"] = nil

dt_buttons = dt_buttons .. formatDropdownEntries({
      {"", i18n("flows_page.all_ip_versions")},
      {"4", i18n("flows_page.ipv4_only")},
      {"6", i18n("flows_page.ipv6_only")},
						 }, base_url, flowhosts_type_params, "version", page_params.ipversion)

dt_buttons = dt_buttons .. "</div>']"

print [[
	 $("#table-flows").datatable({
         url: url_update,
         buttons: ]] print(dt_buttons) print[[,
         tableCallback: function()  {
	    ]] initFlowsRefreshRows() print[[
	 },
	       showPagination: true,
	       ]]

  print('title: "'..active_flows_msg..'",')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if(preference ~= "") then print ('perPage: '..preference.. ",\n") end


print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')

print [[
	        columns: [
           {
        title: "Key",
         field: "key",
         hidden: true
         },
			     {
			     title: "",
				 field: "column_key",
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
                             title: "]] print(i18n("application")) print[[",
				 field: "column_ndpi",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("protocol")) print[[",
				 field: "column_proto_l4",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("client")) print[[",
				 field: "column_client",
				 sortable: true,
				 },
			     {
			     title: "]] print(i18n("server")) print[[",
				 field: "column_server",
				 sortable: true,
				 },
			     {
                             title: "]] print(i18n("duration")) print[[",
				 field: "column_duration",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			       }
			       },
			     {
			     title: "]] print(i18n("flows_page.actual_throughput")) print[[",
				 field: "column_thpt",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }
				 },
			     {
                             title: "]] print(i18n("flows_page.total_bytes")) print[[",
				 field: "column_bytes",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }

				 }
			     ,{
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

end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
