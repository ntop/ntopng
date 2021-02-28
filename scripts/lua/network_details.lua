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
local alert_utils = require "alert_utils"
local page_utils = require("page_utils")
local ts_utils = require("ts_utils")
local ui_utils = require("ui_utils")
local local_network_pools = require ("local_network_pools")

local network        = _GET["network"]
local network_name   = _GET["network_cidr"]
local page           = _GET["page"]

local ifstats = interface.getStats()
local ifId = ifstats.id
local have_nedge = ntop.isnEdge()

if(not isEmptyString(network_name)) then
  network = ntop.getNetworkIdByName(network_name)
else
  network_name = ntop.getNetworkNameById(tonumber(network))
end

local custom_name = getLocalNetworkAlias(network_name)

local network_vlan   = tonumber(_GET["vlan"])
if network_vlan == nil then network_vlan = 0 end

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.networks)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(network == nil) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> ".. i18n("network_details.network_parameter_missing_message") .. "</div>")
    return
end

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/network_details.lua?network="..tonumber(network)
local title = i18n("network_details.network") .. ": "..network_name

page_utils.print_navbar(title, nav_url,
			{
			   {
			      active = page == "historical" or not page,
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			   {
			      hidden = interface.isPcapDumpInterface() or not areAlertsEnabled(),
			      active = page == "alerts",
			      page_name = "alerts",
			      label = "<i class=\"fas fa-exclamation-triangle fa-lg\"></i>",
			   },
			   {
			      hidden = not hasTrafficReport(),
			      active = page == "traffic_report",
			      page_name = "traffic_report",
			      label = "<i class='fas fa-file-alt report-icon'></i>",
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
    local schema = _GET["ts_schema"] or "subnet:traffic"
    local selected_epoch = _GET["epoch"] or ""
    local url = ntop.getHttpPrefix()..'/lua/network_details.lua?ifid='..ifId..'&network='..network..'&page=historical'

    local tags = {
      ifid = ifId,
      subnet = network_name,
    }

    graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = {
	 {schema="subnet:traffic",             label=i18n("traffic"), split_directions = true --[[ split RX and TX directions ]]},
	 {schema="subnet:broadcast_traffic",   label=i18n("broadcast_traffic")},
	 {schema="subnet:engaged_alerts",      label=i18n("show_alerts.engaged_alerts")},
	 {schema="subnet:tcp_retransmissions", label=i18n("graphs.tcp_packets_retr"), nedge_exclude=1},
	 {schema="subnet:tcp_out_of_order",    label=i18n("graphs.tcp_packets_ooo"), nedge_exclude=1},
	 {schema="subnet:tcp_lost",            label=i18n("graphs.tcp_packets_lost"), nedge_exclude=1},
	 {schema="subnet:tcp_keep_alive",      label=i18n("graphs.tcp_packets_keep_alive"), nedge_exclude=1},
      }
    })
elseif (page == "config") then
    if(not isAdministrator()) then
      return
   end

   local local_network_pools_instance = local_network_pools:create()

   print[[
   <form id="network_config" class="form-inline" style="margin-bottom: 0px;" method="post">
   <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[["/>
   <table class="table table-bordered table-striped">]]

    if _SERVER["REQUEST_METHOD"] == "POST" then
      setLocalNetworkAlias(network_name, _POST["custom_name"])
      custom_name = getLocalNetworkAlias(network_name)
      -- bind local network to pool
      if (_POST["pool"]) then
        local_network_pools_instance:bind_member(network_name, tonumber(_POST["pool"]))
      end
    end

   print [[<tr>
	 <th>]] print(i18n("network_details.network_alias")) print[[</th>
	 <td>
         <input type="text" name="custom_name" class="form-control" placeholder="Custom Name" style="width: 280px;" value="]] print(custom_name) print[[ "
         ]] 
         local option_name = ntop.getLocalNetworkAlias(network_name) or nil
         if option_name then
            print[[disabled="disabled"]]
         end
         print[[>
	 </td>
      </tr>]]

  -- Local Network Pool
  print([[
    <tr>
        <th>]].. i18n("pools.pool") ..[[</th>
        <td>
          ]].. ui_utils.render_pools_dropdown(local_network_pools_instance, network_name,"local_network") ..[[
        </td>
    </tr>
  ]])

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

elseif(page == "alerts") then
    alert_utils.printAlertTables("network", network_name,
      "network_details.lua", {network=network}, network_name,
      {enable_label = i18n("show_alerts.trigger_network_alert_descr", {network = network_name})})

elseif page == "traffic_report" then
    dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/traffic_report.lua")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
