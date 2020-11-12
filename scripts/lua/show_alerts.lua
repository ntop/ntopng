--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"

local page_utils = require("page_utils")
local alerts_api = require("alerts_api")
local recording_utils = require "recording_utils"

sendHTTPContentTypeHeader('text/html')

local ifid = interface.getId()

page_utils.set_active_menu_entry(page_utils.menu_entries.detected_alerts)

alert_utils.checkDeleteStoredAlerts()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
page_utils.print_page_title(i18n('alerts_dashboard.alerts'))

local has_engaged_alerts = alert_utils.hasAlerts("engaged", alert_utils.getTabParameters(_GET, "engaged"))
local has_past_alerts = alert_utils.hasAlerts("historical", alert_utils.getTabParameters(_GET, "historical"))
local has_flow_alerts = alert_utils.hasAlerts("historical-flows", alert_utils.getTabParameters(_GET, "historical-flows"))

if ntop.getPrefs().are_alerts_enabled == false then
   print("<div class=\"alert alert alert-warning\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>" .. " " .. i18n("show_alerts.alerts_are_disabled_message") .. "</div>")
--return
elseif not has_engaged_alerts and not has_past_alerts and not has_flow_alerts then
   print("<div class=\"alert alert alert-info\"><i class=\"fas fa-info-circle fa-lg\" aria-hidden=\"true\"></i>" .. " " .. i18n("show_alerts.no_recorded_alerts_message").."</div>")
else

   -- Alerts Table
   alert_utils.drawAlertTables(has_past_alerts, has_engaged_alerts, has_flow_alerts, false, _GET, nil, nil, {
      is_standalone = true
   })

   -- PCAP modal for alert traffic extraction
   local traffic_extraction_available = recording_utils.isActive(ifid) or recording_utils.isExtractionActive(ifid)
   if traffic_extraction_available then 
      alert_utils.drawAlertPCAPDownloadDialog(ifid)
   end

end -- closes if ntop.getPrefs().are_alerts_enabled == false then

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
