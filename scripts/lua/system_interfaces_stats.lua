--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"
local page_utils = require("page_utils")
local internals_utils = require "internals_utils"

if not isAllowedSystemInterface() then
   return
end

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.interfaces_status)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page = _GET["page"] or "overview"

local url = ntop.getHttpPrefix() .. "/lua/system_interfaces_stats.lua?ifid="..interface.getId()
local info = ntop.getInfo()
local title = i18n("system_interfaces_status")

page_utils.print_navbar(title, url,
			{
			   {
			      active = page == "overview" or not page,
			      page_name = "overview",
			      label = "<i class=\"fas fa-home fa-lg\"></i>",
			   },
			   {
			      active = page == "internals",
			      page_name = "internals",
			      label = "<i class=\"fas fa-wrench fa-lg\"></i>",
			   },
			}
)

-- #######################################################

if(page == "overview") then
   print[[
<div id="table-system-interfaces-stats"></div>
<script type='text/javascript'>

$("#table-system-interfaces-stats").datatable({
   title: "",]]

   local preference = tablePreferences("rows_number",_GET["perPage"])
   if preference ~= "" then print ('perPage: '..preference.. ",\n") end

   print[[
   showPagination: true,
   buttons: [],
   url: "]] print(ntop.getHttpPrefix()) print[[/lua/get_system_interfaces_stats.lua",
   columns: [
     {
       field: "column_ifid",
       hidden: true,
     }, {
       title: "]] print(i18n("name")) print[[",
       field: "column_name",
       sortable: true,
       css: {
         textAlign: 'left',
         width: '5%',
       }
     }, {
       title: "]] print(i18n("show_alerts.engaged_alerts")) print[[",
       field: "column_engaged_alerts",
       sortable: true,
       css: {
         textAlign: 'right',
         width: '5%',
       }
     }, {
       title: "]] print(i18n("host_details.active_alerted_flows")) print[[",
       field: "column_alerted_flows",
       sortable: true,
       css: {
         textAlign: 'right',
         width: '5%',
       }
     }, {
       title: "]] print(i18n("system_interfaces_stats.local_hosts")) print[[",
       field: "column_local_hosts",
       sortable: true,
       css: {
         textAlign: 'right',
         width: '5%',
       }
     }, {
       title: "]] print(i18n("system_interfaces_stats.remote_hosts")) print[[",
       field: "column_remote_hosts",
       sortable: true,
       css: {
         textAlign: 'right',
         width: '5%',
       }
     }, {
       title: "]] print(i18n("devices")) print[[",
       field: "column_devices",
       sortable: true,
       css: {
         textAlign: 'right',
         width: '5%',
       }
     }, {
       title: "]] print(i18n("flows")) print[[",
       field: "column_flows",
       sortable: true,
       css: {
         textAlign: 'right',
         width: '5%',
       }
     }, {
       title: "]] print(i18n("details.total_traffic")) print[[",
       field: "column_traffic",
       sortable: true,
       css: {
         textAlign: 'right',
         width: '5%',
       }
     }, {
       title: "]] print(i18n("db_explorer.total_packets")) print[[",
       field: "column_packets",
       sortable: true,
       css: {
         textAlign: 'right',
         width: '5%',
       }
     }, {
       title: "]] print(i18n("if_stats_overview.dropped_packets")) print[[",
       field: "column_drops",
       sortable: true,
       css: {
         textAlign: 'right',
         width: '5%',
       }
     }
   ], tableCallback: function() {
      datatableInitRefreshRows($("#table-system-interfaces-stats"),
                               "column_ifid", 5000,
                               {"column_packets": NtopUtils.addCommas,
                                "column_traffic": NtopUtils.addCommas,
                                "column_flows": NtopUtils.addCommas,
                                "column_devices": NtopUtils.addCommas,
                                "column_remote_hosts": NtopUtils.addCommas,
                                "column_local_hosts": NtopUtils.addCommas,
                                "column_alerted_flows": NtopUtils.addCommas,
                                "column_engaged_alerts": NtopUtils.addCommas});
   },
});
</script>
 ]]

elseif(page == "internals") then
   internals_utils.printInternals(nil, true --[[ hash tables ]], true --[[ periodic activities ]], true --[[ user scripts]])
   -- local base_url = ntop.getHttpPrefix() .. "/lua/system_interfaces_stats.lua?page=internals"
   -- internals_utils.printHashTablesTable(base_url)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
