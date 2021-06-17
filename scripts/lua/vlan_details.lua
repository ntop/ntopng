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
local page           = _GET["page"] -- only historical for now _GET["page"]

interface.select(ifname)
ifId = getInterfaceId(ifname)

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.vlans)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if vlan_id == nil or tonumber(vlan_id) == nil or tonumber(vlan_id) == 0 then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> " .. i18n("vlan_details.vlan_id_parameter_missing_or_invalid_message") .. "</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

if(not areVlanTimeseriesEnabled(ifId)) and (page ~= "config") then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> " .. i18n("vlan_details.no_available_stats_for_vlan_message",{vlan_id=vlan_id, product=info["product"]}).."</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
else

   --[[
      Create Menu Bar with buttons
   --]]
   local nav_url = ntop.getHttpPrefix().."/lua/vlan_details.lua?vlan="..vlan_id
   local title = i18n("vlan")..": "..vlan_id..""

   page_utils.print_navbar(title, nav_url,
			   {
			      {
                  active = page == "historical" or not page,
                  page_name = "historical",
                  label = "<i class='fas fa-lg fa-chart-area'></i>",
			      },
               {
                  active = page == "alerts",
                  page_name = "alerts",
                  url = ntop.getHttpPrefix() .. "/lua/alert_stats.lua",
                  label = "<i class=\"fas fa-exclamation-triangle fa-lg\"></i>",
               },
               {
                  hidden = not network or not isAdministrator(),
                  active = page == "config",
                  page_name = "config",
                  label = "<i class=\"fas fa-cog fa-lg\"></i>",
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
	    {schema="vlan:score",                	  label=i18n("score"), split_directions = true},
         },
      })
   elseif (page == "config") then
      if(not isAdministrator()) then
         return
      end
      print[[
      <form id="vlan_config" class="form-inline" style="margin-bottom: 0px;" method="post">
      <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[["/>
      <table class="table table-bordered table-striped">]]

      if _SERVER["REQUEST_METHOD"] == "POST" then
         setVlanAlias(tonumber(vlan_id), _POST["custom_name"])
         custom_name = getVlanAlias(tonumber(vlan_id))
      end
      custom_name = getVlanAlias(vlan_id)

      print [[<tr>
       <th>]] print(i18n("vlan_details.vlan_alias")) print[[</th>
       <td>
            <input type="text" name="custom_name" class="form-control" placeholder="Custom Name" style="width: 280px;" value="]]print(custom_name)
            print[["]]

            print[[>
                  </td>
                     </tr>
                  ]]

         print[[
            </table>
            <button class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>
            </form>
            <script>
              aysHandleForm("#vlan_config");
            </script>
         ]]

      print[[</table>]]
   end
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

