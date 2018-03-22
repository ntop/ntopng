--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
local template = require "template_utils"
local host_pools_utils = require("host_pools_utils")

interface.select(ifname)
local ifstats = interface.getStats()

local base_url = ntop.getHttpPrefix().."/lua/if_stats.lua"

local page_params = {}
page_params.ifid = ifstats.id
page_params.page = "pools"
local devices_mode_filter = ""

if not isEmptyString(_GET["unassigned_devices"]) then
   page_params.unassigned_devices = _GET["unassigned_devices"]
   devices_mode_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if isAdministrator() and (_POST["member"] ~= nil) and (_POST["pool"] ~= nil) then
  -- change member pool
  host_pools_utils.changeMemberPool(ifstats.id, _POST["member"], _POST["pool"])
  interface.reloadHostPools()
end

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "assign_device_dialog",
      action  = "assignDevicePool(mac_to_assign)",
      title   = i18n("unknown_devices.assign_device_pool"),
      message = i18n("unknown_devices.select_pool", {mac="<span id=\"assign_device_dialog_mac\"></span>"}) ..
        '<br><br><select class="form-control" id="device_target_pool" style="width:15em;" >'..
        poolDropdown(ifstats.id, "")..
        '</select>',
      custom_alert_class = "",
      confirm = i18n("unknown_devices.assign_pool"),
    }
  })
)

local pools = host_pools_utils.getPoolsList(ifstats.id, true --[[no info]])
local no_pools = (#pools < 2)

print [[
      <br>
      <div id="table-mac"></div>]]

if no_pools then
   print("<br><br>"..i18n("notes")..[[<ul>
      <li>]]..i18n("unknown_devices.no_pools")..[[</li>
   </ul>]])
end

print[[
	 <script>

   function assignDevicePool(mac_address) {
      var params = {};
      params.pool = $("#device_target_pool").val();
      params.member = mac_address;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
   }

	 var url_update = "]]

print(getPageUrl(ntop.getHttpPrefix().."/lua/get_unknown_devices_data.lua", page_params))

print ('";')

print [[ 
           $("#table-mac").datatable({
                        title: "Mac List",
			url: url_update , 
]]

print('title: "",\n')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("unknown_devices") ..'","' .. getDefaultTableSortOrder("unknown_devices").. '"] ],')

print('buttons: [')
   local devices_mode = table.clone(page_params)
   print('\'<div class="btn-group pull-right"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..i18n("unknown_devices.filter_devices")..devices_mode_filter..'<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 90px;">')

   devices_mode.unassigned_devices = nil
   print ('<li><a href="')
   print (getPageUrl(base_url, devices_mode))
   print ('#unassigned">'..i18n("unknown_devices.all_devices")..'</a></li>')

   devices_mode.unassigned_devices = "active_only"
   print('<li')
   if page_params.unassigned_devices == devices_mode.unassigned_devices then print(' class="active"') end
   print('><a href="')
   print (getPageUrl(base_url, devices_mode))
   print ('#unassigned">'..i18n("unknown_devices.active_only")..'</a></li>')

   devices_mode.unassigned_devices = "inactive_only"
   print('<li')
   if page_params.unassigned_devices == devices_mode.unassigned_devices then print(' class="active"') end
   print('><a href="')
   print (getPageUrl(base_url, devices_mode))
   print ('#unassigned">'..i18n("unknown_devices.inactive_only")..'</a></li>')

   print('</ul></div>\'')

   print(" ],")

print [[
   showPagination: true,

   columns: [
      {
         field: "key",
         hidden: true,
      }, {
         title: "]] print(i18n("mac_address")) print[[",
         field: "column_mac",
         sortable: true,
         css: {
            textAlign: 'left'
         }
      }, {
         title: "]] print(i18n("mac_stats.manufacturer")) print[[",
         field: "column_manufacturer",
         hidden: true,
         sortable: false,
         css: {
           textAlign: 'left'
         }
      }, {
         title: "]] print(i18n("unknown_devices.device_name")) print[[",
         field: "column_name",
         sortable: true,
         css: {
           textAlign: 'left'
         }
      }, {
         title: "]] print(i18n("unknown_devices.first_seen")) print[[",
         field: "column_first_seen",
         sortable: true,
         css: {
           textAlign: 'left'
         }
      }, {
         title: "]] print(i18n("unknown_devices.last_seen")) print[[",
         field: "column_last_seen",
         sortable: true,
         css: {
           textAlign: 'left'
         }
      }, {
         title: "]] print(i18n("actions")) print[[",
]]

if no_pools then
   print("hidden:true, ")
end

print[[
         sortable: false,
         css: {
           textAlign: 'center'
         }
      }
   ], tableCallback: function() {
      datatableForEachRow("#table-mac", function() {
         var device_mac = $("td:nth-child(1)", $(this)).html();
]]

   if isAdministrator() then
      print[[
         datatableAddActionButtonCallback.bind(this)(7, "mac_to_assign ='" + device_mac + "'; $('#assign_device_dialog_mac').html('" + device_mac +"'); $('#assign_device_dialog').modal('show');", "]] print(i18n("unknown_devices.assign_pool")) print[[");]]
   end

print[[
      });
   },
});
</script>
]]
