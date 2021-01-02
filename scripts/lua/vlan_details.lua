--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    local snmp_utils = require "snmp_utils"
end

require "lua_utils"
local graph_utils = require "graph_utils"
local page_utils = require("page_utils")

local info = ntop.getInfo(false)
local vlan_id        = _GET["vlan"]
local page           = "historical" -- only historical for now _GET["page"]

interface.select(ifname)
ifId = getInterfaceId(ifname)

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.vlans)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if vlan_id == nil or tonumber(vlan_id) == nil or tonumber(vlan_id) == 0 then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("vlan_details.vlan_id_parameter_missing_or_invalid_message") .. "</div>")
    return
end

if(not areVlanTimeseriesEnabled(ifId)) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("vlan_details.no_available_stats_for_vlan_message",{vlan_id=vlan_id, product=info["product"]}).."</div>")

else

   --[[
      Create Menu Bar with buttons
   --]]
   local nav_url = ntop.getHttpPrefix().."/lua/vlan_details.lua?vlan"..vlan_id
   local title = i18n("vlan")..": "..vlan_id

   page_utils.print_navbar(title, nav_url,
			   {
			      {
				 active = page == "historical" or not page,
				 page_name = "historical",
				 label = "<i class='fas fa-lg fa-chart-area'></i>",
			      },
			   }
   )

   --[[
      Selectively render information pages
   --]]
   if page == "historical" then
      local schema = _GET["ts_schema"] or "vlan:traffic"
      local selected_epoch = _GET["epoch"] or ""
      local vlan_url = ntop.getHttpPrefix()..'/lua/vlan_details.lua?ifid='..ifId..'&vlan='..vlan_id..'&page=historical'

      local tags = {
         ifid = ifId,
         vlan = vlan_id,
         protocol = _GET["protocol"],
      }

      graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], vlan_url, selected_epoch, {
         top_protocols = "top:vlan:ndpi",
         timeseries = {
            {schema="vlan:traffic",             	  label=i18n("traffic")},
         },
      })
   end

end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

