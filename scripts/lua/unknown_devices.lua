--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
local template = require "template_utils"
local host_pools_utils = require("host_pools_utils")

interface.select(ifname)
local ifstats = interface.getStats()

--[[
sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "devices_stats"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix() .. "/lua/unknown_devices.lua"
]]
local page_params = {}
local macs_filter = ""

if isAdministrator() and (_POST["member"] ~= nil) and (_POST["pool"] ~= nil) then
  -- change member pool
  host_pools_utils.changeMemberPool(ifstats.id, _POST["member"], _POST["pool"])
  interface.reloadHostPools()
end

--[[local manufacturer = nil
local manufacturer_filter = ""
if(not isEmptyString(_GET["manufacturer"])) then
   manufacturer = _GET["manufacturer"]
   page_params["manufacturer"] = manufacturer
   manufacturer_filter = '<span class="glyphicon glyphicon-filter"></span>'
end
page_params["host_macs_only"] = "true"
]]

local pools = host_pools_utils.getPoolsList(ifstats.id, true --[[no info]])
local no_pools = (#pools < 2)

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "assign_device_dialog",
      action  = "assignDevicePool(mac_to_assign)",
      title   = i18n("unknown_devices.assign_device_pool"),
      message = i18n("unknown_devices.select_pool", {mac="<span id=\"assign_device_dialog_mac\"></span>"}) ..
        '<br><br><select class="form-control" id="device_target_pool" style="width:15em;" '..ternary(no_pools, "disabled", "")..'>'..
        poolDropdown("")..
        '</select>'..ternary(no_pools, "<br><br>"..i18n("unknown_devices.create_pools_first", {url=ntop.getHttpPrefix().."/lua/if_stats.lua?page=pools#create"}), ""),
      custom_alert_class = "",
      confirm = i18n("unknown_devices.assign_pool"),
      confirm_button = "btn-primary "..ternary(no_pools, "disabled", ""),
    }
  })
)

print [[
      <hr>
      <div id="table-mac"></div>
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

local title = i18n("unknown_devices.unassigned_devices")

print('title: "'..title..'",\n')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("unknown_devices") ..'","' .. getDefaultTableSortOrder("unknown_devices").. '"] ],')

print('buttons: [')


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
         datatableAddActionButtonCallback.bind(this)(7, "mac_to_assign ='" + device_mac + "'; $('#assign_device_dialog_mac').html('" + device_mac +"'); $('#assign_device_dialog').modal('show');", "]] print("Assign Pool") print[[");]]
   end

print[[
      });
   },
});
</script>
]]


--~ dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
