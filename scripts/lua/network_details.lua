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

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(network == nil) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Network parameter is missing (internal error ?)</div>")
    return
end

rrdname = dirs.workingdir .. "/" .. ifId .. "/subnetstats/" .. getPathFromKey(network_name) .. "/bytes.rrd"

if(not ntop.exists(rrdname)) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No available stats for network "..network_name.."</div>")
    return
end

--[[
Process form data
--]]
if(_GET["flow_rate_alert_threshold"] ~= nil and _GET["csrf"] ~= nil) then
    if (tonumber(_GET["flow_rate_alert_threshold"]) ~= nil) then
        page = "config"
        local val = ternary(_GET["flow_rate_alert_threshold"] ~= "0", _GET["flow_rate_alert_threshold"], "25")
        ntop.setCache('ntopng.prefs.'..network_name..':'..tostring(network_vlan)..'.flow_rate_alert_threshold', val)
        -- interface.loadHostAlertPrefs(network_name, network_vlan) TODO: decide to implement it for networks
    end
end
if(_GET["syn_alert_threshold"] ~= nil and _GET["csrf"] ~= nil) then
    if (tonumber(_GET["syn_alert_threshold"]) ~= nil) then
        page = "config"
        val = ternary(_GET["syn_alert_threshold"] ~= "0", _GET["syn_alert_threshold"], "10")
        ntop.setCache('ntopng.prefs.'..network_name..':'..tostring(network_vlan)..'.syn_alert_threshold', val)
        -- interface.loadHostAlertPrefs(network_name, network_vlan) TODO: decide to implement it for networks
    end
end
if(_GET["flows_alert_threshold"] ~= nil and _GET["csrf"] ~= nil) then
    if (tonumber(_GET["flows_alert_threshold"]) ~= nil) then
        page = "config"
        val = ternary(_GET["flows_alert_threshold"] ~= "0", _GET["flows_alert_threshold"], "32768")
        ntop.setCache('ntopng.prefs.'..network_name..':'..tostring(network_vlan)..'.flows_alert_threshold', val)
        -- interface.loadHostAlertPrefs(network_name, network_vlan) TODO: decide to implement it for networks
    end
end
if _GET["re_arm_minutes"] ~= nil then
    page = "config"
    ntop.setHashCache(get_re_arm_alerts_hash_name(), get_re_arm_alerts_hash_key(ifId, network_name), _GET["re_arm_minutes"])
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

print("<li><a href=\"#\">Network: "..network_name.."</A> </li>")

if(page == "historical") then
    print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i></a></li>\n")
else
    print("\n<li><a href=\""..nav_url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
end

if(page == "alerts") then
    print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-warning fa-lg\"></i></a></li>\n")
else
    print("\n<li><a href=\""..nav_url.."&page=alerts\"><i class=\"fa fa-warning fa-lg\"></i></a></li>")
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
   
if(network ~= nil) then
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

    host_url = ntop.getHttpPrefix()..'/lua/network_details.lua?ifname='..ifId..'&network='..network..'&page=historical'
    drawRRD(ifId, 'net:'..network_name, rrdfile, _GET["graph_zoom"], host_url, 1, _GET["epoch"], nil, makeTopStatsScriptsArray())

elseif (page == "config") then
    local re_arm_minutes = ""

    if(isAdministrator()) then
        trigger_alerts = _GET["trigger_alerts"]
        if(trigger_alerts ~= nil) then
            if(trigger_alerts == "true") then
                ntop.delHashCache(get_alerts_suppressed_hash_name(ifname), network_name)
            else
                ntop.setHashCache(get_alerts_suppressed_hash_name(ifname), network_name, trigger_alerts)
            end
        end
    end

    re_arm_minutes = ntop.getHashCache(get_re_arm_alerts_hash_name(), get_re_arm_alerts_hash_key(ifId, network_name))
    if re_arm_minutes == "" then re_arm_minutes=default_re_arm_minutes end

    local flow_rate_alter_thresh = ntop.getCache('ntopng.prefs.'..network_name..':'..tostring(network_vlan)..'.flow_rate_alert_threshold')
    local syn_alert_thresh = ntop.getCache('ntopng.prefs.'..network_name..':'..tostring(network_vlan)..'.syn_alert_threshold')
    local flows_alert_thresh = ntop.getCache('ntopng.prefs.'..network_name..':'..tostring(network_vlan)..'.flows_alert_threshold')
    if (flow_rate_alter_thresh == nil or flow_rate_alter_thresh == "") then flow_rate_alter_thresh = 25 end
    if (syn_alert_thresh == nil or syn_alert_thresh == "") then syn_alert_thresh = 10 end
    if (flows_alert_thresh == nil or flows_alert_thresh == "") then flows_alert_thresh = 32768 end
    print("<table class=\"table table-striped table-bordered\">\n")
    print("<tr><th width=250>Network Flow Alert Threshold</th>\n")
    print [[<td>]]
    print[[<form class="form-inline" style="margin-bottom: 0px;">
    <input type="hidden" name="network" value="]] print(network) print [[">]]
    print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
    print('<input type="number" name="flow_rate_alert_threshold" placeholder="" min="0" step="1" max="100000" value="')
    print(tostring(flow_rate_alter_thresh))
        print [["></input>
	&nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
<small>
    Max number of new flows/sec over which the network is considered to be flooding (<b>Experimental</b>). Default: 25.<br>
    </small>]]
  print[[
    </td></tr>
    ]]

    print("<tr><th width=250>Network SYN Alert Threshold</th>\n")
    print [[<td>]]
   print[[<form class="form-inline" style="margin-bottom: 0px;">
    <input type="hidden" name="network" value="]]
    print(network)
    print [[">]]
    print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
    print [[<input type="number" name="syn_alert_threshold" placeholder="" min="0" step="5" max="100000" value="]]
    print(tostring(syn_alert_thresh))
         print [["></input>
      &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
    <small>
    Max number of sent TCP SYN packets/sec over which the network is considered to be flooding (<b>Experimental</b>). Default: 10.<br>
    </small>]]
    print[[
    </td></tr>
    ]]

    print("<tr><th width=250>Network Flows Threshold</th>\n")
    print [[<td>]]
    print[[<form class="form-inline" style="margin-bottom: 0px;">
    <input type="hidden" name="network" value="]]
    print(network)
    print [[">]]
    print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
    print [[<input type="number" name="flows_alert_threshold" placeholder="" min="0" step="1" max="100000" value="]]
    print(tostring(flows_alert_thresh))
         print [["></input>
      &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
    <small>
    Max number of flows over which the network is considered to be flooding (<b>Experimental</b>). Default: 32768.<br>
    </small>]]
    print[[
    </td></tr>
    ]]

    local suppressAlerts = ntop.getHashCache(get_alerts_suppressed_hash_name(ifname), network_name)
    if((suppressAlerts == "") or (suppressAlerts == nil) or (suppressAlerts == "true")) then
        alerts_checked = 'checked="checked"'
        alerts_value = "false" -- Opposite
    else
        alerts_checked = ""
        alerts_value = "true" -- Opposite
    end

    print [[
         <tr><th>Network Alerts</th><td nowrap>
         <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
         <input type="hidden" name="tab" value="alerts_preferences">
    <input type="hidden" name="network" value="]]
    print(network)
    print('"><input type="hidden" name="trigger_alerts" value="'..alerts_value..'"><input type="checkbox" value="1" '..alerts_checked..' onclick="this.form.submit();"> <i class="fa fa-exclamation-triangle fa-lg"></i> Trigger alerts for network '..network_name..'</input>')
    print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
    print('<input type="hidden" name="page" value="config">')
    print('</form>')
    print('</td>')
    print [[</tr>]]

    print[[<tr><form class="form-inline" style="margin-bottom: 0px;">
      <input type="hidden" name="tab" value="alerts_preferences">
        <input type="hidden" name="network" value="]]
        print(network)
      print[["><input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
         <td style="text-align: left; white-space: nowrap;" ><b>Rearm minutes</b></td>
         <td>
            <input type="number" name="re_arm_minutes" min="1" value=]] print(tostring(re_arm_minutes)) print[[>
            &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
            <br><small>The rearm is the dead time between one alert generation and the potential generation of the next alert of the same kind. </small>
         </td>
      </form></tr>]]

    print("</table>")

elseif(page == "alerts") then

    drawAlertSourceSettings(network_name,
        i18n("show_alerts.network_delete_config_btn"), i18n("show_alerts.network_delete_config_confirm"),
        "network_details.lua", {network=network})

elseif page == "traffic_report" then
    dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/traffic_report.lua")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
