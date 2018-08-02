--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local discover = require "discover_utils"
local ifId = getInterfaceId(ifname)
local refresh_button = '<small><a href="'..ntop.getHttpPrefix()..'/lua/discover.lua?request_discovery=true" title="Refresh"><i class="fa fa-refresh fa-sm" aria-hidden="true"></i></a></small>'

active_page = "dashboard"

if _GET["request_discovery"] == "true" then
   refresh_button = ""
   discover.requestNetworkDiscovery(ifId)
end

local os_filter = _GET["operating_system"]
local manuf_filter = _GET["manufacturer"]
local devtype_filter = _GET["device_type"]
local base_url = ntop.getHttpPrefix() .. "/lua/discover.lua"
local page_params = {}

if(not isEmptyString(os_filter)) then
   page_params.operating_system = os_filter
end
if(not isEmptyString(manuf_filter)) then
   page_params.manufacturer = manuf_filter
end
if(not isEmptyString(devtype_filter)) then
   page_params.device_type = devtype_filter
end

local discovery_requested = discover.networkDiscoveryRequested(ifId)

if discovery_requested then
   refresh_button = ""
end

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- print('<hr><H2>'..i18n("discover.network_discovery")..'&nbsp;</H2><br>')
print('<hr><H2>'..i18n("discover.network_discovery")..'&nbsp;'..refresh_button..'</H2><br>')

local discovered = discover.discover2table(ifname)
local manufactures = {}
local operating_systems = {}
local device_types = {}

for _, device in pairs(discovered["devices"] or {}) do
   local manuf = (device["manufacturer"] or get_manufacturer_mac(device["mac"]))
   if(manuf ~= nil) then
      manufactures[manuf] = manufactures[manuf] or 0
      manufactures[manuf] = manufactures[manuf] + 1
   end

   local dev_os = device["os_type"]
   if(dev_os ~= nil) then
      operating_systems[dev_os] = operating_systems[dev_os] or 0
      operating_systems[dev_os] = operating_systems[dev_os] + 1
   end

   local dev_type = discover.devtype2id(device["device_type"])
   if(dev_type ~= nil) then
      device_types[dev_type] = device_types[dev_type] or 0
      device_types[dev_type] = device_types[dev_type] + 1
   end
end

if discovery_requested then

   print('<div class=\"alert alert-info alert-dismissable\">'..'<img src="'..ntop.getHttpPrefix()..'/img/loading.gif"> '..i18n('discover.network_discovery_not_enabled', {url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=discovery", flask_icon="<i class=\"fa fa-flask\"></i>"})..'<span id="discovery-progress"></span>.</div>')

   print[[

<script type="text/javascript">
(function worker() {
  xhr = $.ajax({
    type: 'GET',]]
print("url: '"..ntop.getHttpPrefix().."/lua/get_discover_progress.lua?ifid="..tostring(ifId).."', ")
print[[
    complete: function() {
    },
    error: function() {
    },
    success: function(msg){
      console.log(msg);
      if(msg.discovery_requested == true) {
        if(msg.progress != "") {
          $('#discovery-progress').html(" " + msg.progress);
        }
        // Schedule the next request when the current one's complete
        setTimeout(worker, 3000);
      } else {
        window.location.href=']] print(ntop.getHttpPrefix()) print[[/lua/discover.lua';
      }
    }
  });
})();

</script>

]]

elseif discovered["status"]["code"] == "NOCACHE" then
   -- nothing to show and nothing has been requested
   print('<div class=\"alert alert-info alert-dismissable\"><i class="fa fa-info-circle fa-lg"></i>&nbsp;'..discovered["status"]["message"]..'</div>')
end

if discovered["status"]["code"] == "ERROR" then
   print('<div class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i>&nbsp;'..discovered["status"]["message"]..'</div>')

elseif discovered["status"]["code"] == "OK" then -- everything is ok
   print[[<div id="discover-table"></div>]]

   print[[<script>
      var dt_discover = $("#discover-table").datatable({
         url: "]] print(getPageUrl(ntop.getHttpPrefix() .. "/lua/get_discover_data.lua", page_params)) print[[",
         title: "",
         showPagination: true,
         class: "table table-striped table-bordered table-condensed",
         buttons: []]

   -- Manufacturer filter
   print('\'<div class="btn-group pull-right"><div class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..
      i18n("mac_stats.manufacturer") .. ternary(not isEmptyString(manuf_filter), '<span class="glyphicon glyphicon-filter"></span>', '') ..
      '<span class="caret"></span></div> <ul class="dropdown-menu" role="menu" style="min-width: 90px;">')

   local manuf_params = table.clone(page_params)
   manuf_params.manufacturer = nil
   print('<li><a href="' .. getPageUrl(base_url, manuf_params) .. '">' .. i18n("mac_stats.all_manufacturers") .. '</a></li>')

   for manuf, count in pairsByKeys(manufactures) do
      local _manuf = string.gsub(string.gsub(manuf, "'", "&#39;"), "\"", "&quot;")
      manuf_params.manufacturer = manuf
      print('<li' .. ternary(manuf_filter == manuf, ' class="active"', '') .. '><a href="' ..
         getPageUrl(base_url, manuf_params) .. '">' ..
         _manuf .." (" ..count.. ')</a></li>')
   end
   print('</ul></div>\',')

   -- Device Type filter
   local type_params = table.clone(page_params)
   print('\'<div class="btn-group"><div class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..
      i18n("details.device_type") .. ternary(not isEmptyString(devtype_filter), '<span class="glyphicon glyphicon-filter"></span>', '') ..
      '<span class="caret"></span></div> <ul class="dropdown-menu" role="menu" style="min-width: 90px;">')

   type_params.device_type = nil
   print('<li><a href="' .. getPageUrl(base_url, type_params) .. '">' .. i18n("mac_stats.all_devices") .. '</a></li>')

   for devtype, count in pairsByKeys(device_types) do
      type_params.device_type = devtype

      print('<li' .. ternary(devtype_filter == tostring(devtype), ' class="active"', '') .. '><a href="' ..
         getPageUrl(base_url, type_params) .. '">' ..
         discover.devtype2string(devtype)  .." (" ..count.. ')</a></li>')
   end
   print('</ul></div>\',')

   -- OS filter
   local os_params = table.clone(page_params)
   print('\'<div class="btn-group"><div class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..
      i18n("os") .. ternary(not isEmptyString(os_filter), '<span class="glyphicon glyphicon-filter"></span>', '') ..
      '<span class="caret"></span></div> <ul class="dropdown-menu" role="menu" style="min-width: 90px;">')

   os_params.operating_system = nil
   print('<li><a href="' .. getPageUrl(base_url, os_params) .. '">' .. i18n("mac_stats.all_devices") .. '</a></li>')

   for osid, count in pairsByKeys(operating_systems) do
      local os_name = getOperatingSystemName(osid)
      if isEmptyString(os_name) then os_name = i18n("unknown") end
      os_params.operating_system = osid

      print('<li' .. ternary(os_filter == tostring(osid), ' class="active"', '') .. '><a href="' ..
         getPageUrl(base_url, os_params) .. '">' .. --(getOperatingSystemIcon(osid):gsub("'",'"') or "") ..
         os_name  .." (" ..count.. ')</a></li>')
   end
   print('</ul></div>\'],')

   -- Set the preference table
   local preference = tablePreferences("rows_number_discovery", _GET["perPage"])
   if not isEmptyString(preference) then
      print ('perPage: '..preference.. ",\n")
   end

   print [[
         columns: [{
            title: "]] print(i18n("ip_address")) print[[",
            field: "column_ip",
            //sortable: "true", /* cannot sort ip right now */
         }, {
            title: "]] print(i18n("name")) print[[",
            field: "column_name",
            sortable: "true",
         }, {
            title: "]] print(i18n("mac_stats.manufacturer")) print[[",
            field: "column_manufacturer",
            sortable: "true",
         }, {
            title: "]] print(i18n("mac_address")) print[[",
            field: "column_mac",
            sortable: "true",
         }, {
            title: "]] print(i18n("os")) print[[",
            field: "column_os",
            sortable: "true",
            css: {
	       textAlign: 'center'
	    }
         }, {
            title: "]] print(i18n("info")) print[[",
            field: "column_info",
            sortable: "true",
         }, {
            title: "]] print(i18n("discover.device")) print[[",
            field: "column_device",
            sortable: "true",
         }
         ]
      });
   </script>]]

   print("<p>"..i18n("discover.network_discovery_datetime")..": "..formatEpoch(discovered["discovery_timestamp"]).."</p>")
end

if(discovered["ghost_found"]) then
   print('<b>' .. i18n("notes") .. '</b> ' .. i18n("discover.ghost_icon_descr", {ghost_icon='<font color=red>'..discover.ghost_icon..'</font>'}) .. '.')
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
