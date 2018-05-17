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

if discovery_requested then
   print("<script>setTimeout(function(){window.location.href='"..ntop.getHttpPrefix().."/lua/discover.lua'}, 5000);</script>")   
   print('<div class=\"alert alert-info alert-dismissable\"><i class="fa fa-info-circle fa-lg"></i>&nbsp;'..i18n('discover.network_discovery_not_enabled', {url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=discovery", flask_icon="<i class=\"fa fa-flask\"></i>"}).." " .. discover.getDiscoveryProgress() .." "..'</div>')

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
         url: "]] print(ntop.getHttpPrefix()) print[[/lua/get_discover_data.lua",
         title: "",
         showPagination: true,
         class: "table table-striped table-bordered table-condensed",
         ]]

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
end

if(discovered["ghost_found"]) then
   print('<b>' .. i18n("notes") .. '</b>: ' .. i18n("discover.ghost_icon_descr", {ghost_icon='<font color=red>'..discover.ghost_icon..'</font>'}) .. '.')
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
