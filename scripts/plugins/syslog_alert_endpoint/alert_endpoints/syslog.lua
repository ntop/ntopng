--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"

local syslog = {}

syslog.DEFAULT_SEVERITY = "info"
syslog.EXPORT_FREQUENCY = 1 -- 1 second, i.e., as soon as possible
syslog.prio = 300

-- ##############################################

function syslog.isAvailable()
   return(ntop.syslog ~= nil)
end

-- ##############################################

function syslog.dequeueAlerts(queue)
   local notifications = ntop.lrangeCache(queue, 0, -1)

   if not notifications then
      return {success = true}
   end

   local syslog_format = ntop.getPref("ntopng.prefs.syslog_alert_format")
   if isEmptyString(syslog_format) then
      syslog_format = "plaintext"
   end

   -- Separate by severity and channel
   local alerts_by_types = {}

   for _, json_message in ipairs(notifications) do
      local notif = json.decode(json_message)
      if notif.alert_entity then
         alerts_by_types[notif.alert_entity] = alerts_by_types[notif.alert_entity] or {}
         alerts_by_types[notif.alert_entity][notif.alert_severity] = alerts_by_types[notif.alert_entity][notif.alert_severity] or {}
         table.insert(alerts_by_types[notif.alert_entity][notif.alert_severity], notif)
      end
   end

   for _, by_severity in pairs(alerts_by_types) do
      for severity, notifications in pairs(by_severity) do
        severity = alert_consts.alertSeverityRaw(severity)

	 -- Most recent notifications first
	 for _, notif in pairsByValues(notifications, alert_utils.notification_timestamp_rev) do
	    local syslog_severity = alert_consts.alertLevelToSyslogLevel(severity)

	    local msg

	    if syslog_format == "plaintext" then
	       -- prepare a plaintext message
	       msg = alert_utils.formatAlertNotification(notif, {nohtml = true,
						     show_severity = true,
						     show_entity = true})
	    else -- syslog_format == "json" then
	       -- send out the json message but prepare a nice
	       -- message
	       notif.message  = alert_utils.formatAlertNotification(notif, {nohtml = true,
								show_severity = false,
								show_entity = false})
	       msg = json.encode(notif)
	    end

	    ntop.syslog(msg, syslog_severity)
	 end
      end
   end

   -- Remove all the messages from queue on success
   ntop.delCache(queue)

   return {success = true}
end

-- ##############################################

function syslog.printPrefs(alert_endpoints, subpage_active, showElements)
   print('<thead class="thead-light"><tr><th colspan="2" class="info">'..i18n("prefs.syslog_notification")..'</th></tr></thead>')

   local alertsEnabled = showElements
   local elementToSwitch = {"row_syslog_alert_format"}

   prefsToggleButton(subpage_active, {
     field = "toggle_alert_syslog",
     pref = alert_endpoints.getAlertNotificationModuleEnableKey("syslog", true),
     default = "0",
     disabled = alertsEnabled == false,
     to_switch = elementToSwitch,
   })

   local format_labels = {i18n("prefs.syslog_alert_format_plaintext"), i18n("prefs.syslog_alert_format_json")}
   local format_values = {"plaintext", "json"}

   if ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey("syslog")) == "0" then
     alertsEnabled = false
   end

   multipleTableButtonPrefs(subpage_active.entries["syslog_alert_format"].title,
       subpage_active.entries["syslog_alert_format"].description,
       format_labels, format_values,
       "plaintext",
       "primary",
       "syslog_alert_format",
       "ntopng.prefs.syslog_alert_format", nil,
       nil, nil, nil, alertsEnabled)
end

-- ##############################################

return syslog
