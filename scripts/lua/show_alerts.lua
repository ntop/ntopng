--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

local page_utils = require("page_utils")
local alerts_api = require("alerts_api")

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.detected_alerts)

checkDeleteStoredAlerts()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local has_engaged_alerts = hasAlerts("engaged", getTabParameters(_GET, "engaged"))
local has_past_alerts = hasAlerts("historical", getTabParameters(_GET, "historical"))
local has_flow_alerts = hasAlerts("historical-flows", getTabParameters(_GET, "historical-flows"))
local has_disabled_alerts = alerts_api.hasEntitiesWithAlertsDisabled(interface.getId())

if ntop.getPrefs().are_alerts_enabled == false then
   print("<div class=\"alert alert alert-warning\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>" .. " " .. i18n("show_alerts.alerts_are_disabled_message") .. "</div>")
--return
elseif not has_engaged_alerts and not has_past_alerts and not has_flow_alerts and not has_disabled_alerts then
   print("<div class=\"alert alert alert-info\"><i class=\"fas fa-info-circle fa-lg\" aria-hidden=\"true\"></i>" .. " " .. i18n("show_alerts.no_recorded_alerts_message",{ifname=ifname}).."</div>")
else
   drawAlertTables(has_past_alerts, has_engaged_alerts, has_flow_alerts, has_disabled_alerts, _GET)
end -- closes if ntop.getPrefs().are_alerts_enabled == false then

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
