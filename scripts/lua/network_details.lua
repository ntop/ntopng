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
local tag_utils = require("tag_utils")
local page_utils = require("page_utils")
local ts_utils = require("ts_utils")
local ui_utils = require("ui_utils")
local local_network_pools = require ("local_network_pools")
local auth = require "auth"

local network        = _GET["network"]
local network_name   = _GET["network_cidr"]
local page           = _GET["page"]

local network_behavior_update_freq = 300 -- Seconds

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
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> ".. i18n("network_details.network_parameter_missing_message") .. "</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
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

    local all_timeseries = {
      {schema="subnet:traffic",             label=i18n("traffic"), split_directions = true --[[ split RX and TX directions ]]},
      {schema="subnet:broadcast_traffic",   label=i18n("broadcast_traffic")},
      {schema="subnet:engaged_alerts",      label=i18n("show_alerts.engaged_alerts")},
      {schema="subnet:score",               label=i18n("score"), split_directions = true},
      {schema="subnet:tcp_retransmissions", label=i18n("graphs.tcp_packets_retr"), nedge_exclude=1},
      {schema="subnet:tcp_out_of_order",    label=i18n("graphs.tcp_packets_ooo"), nedge_exclude=1},
      {schema="subnet:tcp_lost",            label=i18n("graphs.tcp_packets_lost"), nedge_exclude=1},
      {schema="subnet:tcp_keep_alive",      label=i18n("graphs.tcp_packets_keep_alive"), nedge_exclude=1},
    }

    if ntop.isPro() then
      local pro_timeseries = {
        {schema="subnet:score_anomalies",     label=i18n("graphs.iface_score_anomalies")},
        {schema="subnet:score_behavior",      label=i18n("graphs.iface_score_behavior"), split_directions = true, first_timeseries_only = true, metrics_labels = {i18n("graphs.score"), i18n("graphs.lower_bound"), i18n("graphs.upper_bound")}},
        {schema="subnet:traffic_anomalies",   label=i18n("graphs.iface_traffic_anomalies")},
        {schema="subnet:traffic_rx_behavior_v2", label=i18n("graphs.iface_traffic_rx_behavior"), split_directions = true, first_timeseries_only = true, time_elapsed = network_behavior_update_freq, value_formatter = {"NtopUtils.fbits_from_bytes", "NtopUtils.bytesToSize"}, metrics_labels = {i18n("graphs.traffic_rcvd"), i18n("graphs.lower_bound"), i18n("graphs.upper_bound")}},
        {schema="subnet:traffic_tx_behavior_v2", label=i18n("graphs.iface_traffic_tx_behavior"), split_directions = true, first_timeseries_only = true, time_elapsed = network_behavior_update_freq,value_formatter = {"NtopUtils.fbits_from_bytes", "NtopUtils.bytesToSize"}, metrics_labels = {i18n("graphs.traffic_sent"), i18n("graphs.lower_bound"), i18n("graphs.upper_bound")}},
      }
      all_timeseries = table.merge(all_timeseries, pro_timeseries)
    end

    graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = all_timeseries,
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
         <input type="text" name="custom_name" class="form-control" placeholder="Custom Name" style="width: 280px;" value="]] print(custom_name) print[["
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

elseif page == "traffic_report" then
   package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/?.lua;" .. package.path
   local traffic_report = require "traffic_report"

   traffic_report.generate_traffic_report()
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
