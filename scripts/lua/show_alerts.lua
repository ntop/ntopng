--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

interface.select(ifname)

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

checkDeleteStoredAlerts()

active_page = "alerts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local num_engaged_alerts = getNumAlerts("engaged", getTabParameters(_GET, "engaged"))
local num_past_alerts = getNumAlerts("historical", getTabParameters(_GET, "historical"))
local num_flow_alerts = getNumAlerts("historical-flows", getTabParameters(_GET, "historical-flows"))

if ntop.getPrefs().are_alerts_enabled == false then
   print("<div class=\"alert alert alert-warning\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>" .. " " .. i18n("show_alerts.alerts_are_disabled_message") .. "</div>")
--return
elseif num_past_alerts == 0 and num_flow_alerts == 0 and num_engaged_alerts == 0 then
   print("<div class=\"alert alert alert-info\"><i class=\"fa fa-info-circle fa-lg\" aria-hidden=\"true\"></i>" .. " " .. i18n("show_alerts.no_recorded_alerts_message",{ifname=ifname}).."</div>")
else
   drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, _GET)
end -- closes if ntop.getPrefs().are_alerts_enabled == false then

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
