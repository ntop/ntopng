--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    require "snmp_utils"
end

require "lua_utils"
require "graph_utils"
require "alert_utils"
active_page = "hosts"
local page_utils = require("page_utils")
local ts_utils = require("ts_utils")

local network        = _GET["network"]
local network_name   = _GET["network_cidr"]
local page           = _GET["page"]

interface.select(ifname)
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

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(network == nil) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> ".. i18n("network_details.network_parameter_missing_message") .. "</div>")
    return
end

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/network_details.lua?network="..tonumber(network)
print [[
<div class="bs-docs-example">
	    <nav class="navbar navbar-default" role="navigation">
	      <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">" .. i18n("network_details.network") .. ": "..network_name.."</A> </li>")

if(page == "historical") then
    print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i></a></li>\n")
else
    print("\n<li><a href=\""..nav_url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
end

if areAlertsEnabled() then
    if(page == "alerts") then
	print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-warning fa-lg\"></i></a></li>\n")
    else
	print("\n<li><a href=\""..nav_url.."&page=alerts\"><i class=\"fa fa-warning fa-lg\"></i></a></li>")
    end
end

if ts_utils.getDriverName() == "rrd" then
   if ntop.isEnterprise() or ntop.isnEdge() then
      if(page == "traffic_report") then
	 print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-file-text report-icon'></i></a></li>\n")
      else
	 print("\n<li><a href=\""..nav_url.."&page=traffic_report\"><i class='fa fa-file-text report-icon'></i></a></li>")
      end
   else
      print("\n<li><a href=\"#\" title=\""..i18n('enterpriseOnly').."\"><i class='fa fa-file-text report-icon'></i></A></li>\n")
   end
end

if((network ~= nil) and (areAlertsEnabled())) then
    if(page == "config") then
	print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-cog fa-lg\"></i></a></li>\n")

    else
	print("\n<li><a href=\""..nav_url.."&page=config\"><i class=\"fa fa-cog fa-lg\"></i></a></li>")
    end
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
]]

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

    drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
      timeseries = {
	 {schema="subnet:traffic",             label=i18n("traffic")},
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
	       <input type="text" name="custom_name" class="form-control" placeholder="Custom Name" style="width: 280px;" value="]] print(custom_name) print[[">
	 </td>
      </tr>]]

   print[[
   </table>
   <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>
   </form>
   <script>
     aysHandleForm("#network_config");
   </script>]]

elseif(page == "alerts") then

    drawAlertSourceSettings("network", network_name,
	i18n("show_alerts.network_delete_config_btn", {network=network_name}), "show_alerts.network_delete_config_confirm",
	"network_details.lua", {network=network}, network_name, "network")

elseif page == "traffic_report" then
    dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/traffic_report.lua")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
