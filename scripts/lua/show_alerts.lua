--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

interface.select(ifname)

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

checkDeleteStoredAlerts()

active_page = "alerts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local alert_opts = UrlToalertsQueryParameters(_GET)
local num_engaged_alerts = getNumAlerts("engaged", alert_opts)
local num_past_alerts = getNumAlerts("historical", alert_opts)
local num_flow_alerts = getNumAlerts("historical-flows", alert_opts)

if ntop.getPrefs().are_alerts_enabled == false then
   print("<div class=\"alert alert alert-warning\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Alerts are disabled. Please check the preferences page to enable them.</div>")
--return
elseif num_alerts == 0 and num_flow_alerts == 0 and num_engaged_alerts == 0 then
   print("<div class=\"alert alert alert-info\"><i class=\"fa fa-info-circle fa-lg\" aria-hidden=\"true\"></i>" .. " No recorded alerts for interface "..ifname.."</div>")
else
   drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, _GET)
end -- closes if ntop.getPrefs().are_alerts_enabled == false then

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
