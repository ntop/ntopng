--
-- (C) 2013-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    local snmp_utils = require "snmp_utils"
end

require "lua_utils"
local graph_utils = require "graph_utils"
local tag_utils = require("tag_utils")
local page_utils = require("page_utils")
local auth = require "auth"

local network_id        = _GET["network"]
local network_name   = _GET["network_cidr"]
local page           = _GET["page"]
local subnet2        = _GET["subnet_2"]

local network_behavior_update_freq = 300 -- Seconds

local ifstats = interface.getStats()
local ifId = ifstats.id

if(not isEmptyString(network_name)) then
  network_id = ntop.getNetworkIdByName(network_name)
else
  network_name = ntop.getNetworkNameById(tonumber(network_id))
end

local custom_name = getLocalNetworkAlias(network_name)

local network_vlan   = tonumber(_GET["vlan"])
if network_vlan == nil then network_vlan = 0 end

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.networks)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(network_id == nil) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> ".. i18n("network_details.network_parameter_missing_message") .. "</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/network_details.lua?network="..tonumber(network_id)
local title = i18n("network_details.network") .. ": "..custom_name

page_utils.print_navbar(title, nav_url,
			{
			   {
			      active = page == "historical" or not page,
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			   {
			      hidden = not areAlertsEnabled() or  not auth.has_capability(auth.capabilities.alerts),
			      active = page == "alerts",
			      page_name = "alerts",
			      url = ntop.getHttpPrefix() .. "/lua/alert_stats.lua?&page=network&network_name=" .. network_name .. tag_utils.SEPARATOR .. "eq",
			      label = "<i class=\"fas fa-exclamation-triangle fa-lg\"></i>",
			   },
			   {
			      hidden = not hasTrafficReport(),
			      active = page == "traffic_report",
			      page_name = "traffic_report",
			      label = "<i class='fas fa-file-alt report-icon'></i>",
			   },
			   {
			      hidden = not network_id or not isAdministrator(),
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
   graph_utils.drawNewGraphs(network_name, interface.getId())
elseif (page == "config") then
    if(not isAdministrator()) then
      return
   end

   print[[
   <form id="network_config" class="form-inline" style="margin-bottom: 0px;" method="post">
   <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[["/>
   <table class="table table-bordered table-striped">]]

    if _SERVER["REQUEST_METHOD"] == "POST" then
      setLocalNetworkAlias(network_name, _POST["custom_name"])
      custom_name = getLocalNetworkAlias(network_name)
    end

   print [[<tr>
	 <th>]] print(i18n("network_details.network_alias")) print[[</th>
	 <td>
         <input type="text" name="custom_name" class="form-control" placeholder="Custom Name" style="width: 280px;" value="]] print(custom_name) print[["
         ]] 
         local option_name = ntop.getLocalNetworkAlias(network_name) or nil
         if option_name then
            print[[disabled="disabled"]]
         end
         print[[>
	 </td>
      </tr>]]

   print[[
   </table>
   <button class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>
   </form>
   <script>
     aysHandleForm("#network_config");
   </script>]]

  print([[
    <div class="notes bg-light border">
      <b>]] .. i18n("notes") .. [[</b>:
      <ul>
        <li>
          ]] ..  i18n("network_stats.note_aliases_not_configurable") .. [[ 
      </ul>
    </div>
  ]])

elseif page == "traffic_report" then
   package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/?.lua;" .. package.path
   local traffic_report = require "traffic_report"

   traffic_report.generate_traffic_report()
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
