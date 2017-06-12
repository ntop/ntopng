--
-- (C) 2013-17 - ntop.org
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

local network        = _GET["network"]
local page           = _GET["page"]

interface.select(ifname)
ifstats = interface.getStats()
ifId = ifstats.id

local network_name = ntop.getNetworkNameById(tonumber(network))
local network_vlan   = tonumber(_GET["vlan"])
if network_vlan == nil then network_vlan = 0 end

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(network == nil) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> ".. i18n("network_details.network_parameter_missing_message") .. "</div>")
    return
end

rrdname = dirs.workingdir .. "/" .. ifId .. "/subnetstats/" .. getPathFromKey(network_name) .. "/bytes.rrd"

if(not ntop.exists(rrdname)) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("network_details.no_available_stats_for_network",{network=network_name}) .. "</div>")
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

   if(ntop.isEnterprise()) then
      if(page == "traffic_report") then
         print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-file-text report-icon'></i></a></li>\n")
      else
         print("\n<li><a href=\""..nav_url.."&page=traffic_report\"><i class='fa fa-file-text report-icon'></i></a></li>")
      end
   else
      print("\n<li><a href=\"#\" title=\""..i18n('enterpriseOnly').."\"><i class='fa fa-file-text report-icon'></i></A></li>\n")
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
    if(_GET["rrd_file"] == nil) then
        rrdfile = "bytes.rrd"
    else
        rrdfile=_GET["rrd_file"]
    end

    host_url = ntop.getHttpPrefix()..'/lua/network_details.lua?ifid='..ifId..'&network='..network..'&page=historical'
    drawRRD(ifId, 'net:'..network_name, rrdfile, _GET["zoom"], host_url, 1, _GET["epoch"], nil, makeTopStatsScriptsArray())

elseif (page == "config") then
    if(not isAdministrator()) then
      return
   end

   print[[
   <table class="table table-bordered table-striped">]]

   -- Alerts
   local trigger_alerts = true
   local trigger_alerts_checked = "checked"

   if (_POST["trigger_alerts"] ~= nil) then
      if _POST["trigger_alerts"] ~= "true" then
         trigger_alerts = false
         trigger_alerts_checked = ""
      end

      ntop.setHashCache(get_alerts_suppressed_hash_name(getInterfaceId(ifname)), network_name, tostring(trigger_alerts))
   else
      trigger_alerts = ntop.getHashCache(get_alerts_suppressed_hash_name(getInterfaceId(ifname)), network_name)
      if trigger_alerts == "false" then
         trigger_alerts = false
         trigger_alerts_checked = ""
      end
   end

      print [[<tr>
         <th>]] print(i18n("network_alert_config.trigger_network_alerts")) print[[</th>
         <td>
            <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">
               <input type="hidden" name="trigger_alerts" value="]] print(not trigger_alerts) print[[">
               <input type="checkbox" value="1" ]] print(trigger_alerts_checked) print[[ onclick="this.form.submit();">
                  <i class="fa fa-exclamation-triangle fa-lg"></i>
                  ]] print(i18n("network_alert_config.trigger_alerts_for_network",{network=network_name})) print[[
               </input>
               <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[["/>
            </form>
         </td>
      </tr>]]

   print[[
   </table>]]

elseif(page == "alerts") then

    drawAlertSourceSettings("network", network_name,
        i18n("show_alerts.network_delete_config_btn", {network=network_name}), "show_alerts.network_delete_config_confirm",
        "network_details.lua", {network=network})

elseif page == "traffic_report" then
    dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/traffic_report.lua")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
