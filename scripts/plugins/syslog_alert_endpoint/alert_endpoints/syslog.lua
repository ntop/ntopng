--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"

local syslog = {
   conf_params = {
      { param_name = "syslog_alert_format" },
   },
   conf_template = {
      plugin_key = "syslog_alert_endpoint",
      template_name = "syslog_endpoint.template"
   },
   recipient_params = {
   },
   recipient_template = {
      plugin_key = "syslog_alert_endpoint",
      template_name = "syslog_recipient.template" -- TODO: add template
   },
}

syslog.DEFAULT_SEVERITY = "info"
syslog.EXPORT_FREQUENCY = 1 -- 1 second, i.e., as soon as possible
syslog.prio = 300

-- ##############################################

function syslog.isAvailable()
   return(ntop.syslog ~= nil)
end

-- ##############################################

-- Dequeue alerts from a recipient queue for sending notifications
function syslog.dequeueRecipientAlerts(recipient, budget)

   local notifications = ntop.lrangeCache(recipient.export_queue, 0, budget-1)

   if not notifications or #notifications == 0 then
      return {success = true}
   end

   local syslog_format = recipient.endpoint_conf.endpoint_conf.syslog_alert_format
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
      for severity, sev_notifications in pairs(by_severity) do
        severity = alert_consts.alertSeverityRaw(severity)

	 -- Most recent notifications first
	 for _, notif in pairsByValues(sev_notifications, alert_utils.notification_timestamp_rev) do
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

   -- Remove the processed messages from the queue
   ntop.ltrimCache(recipient.export_queue, #notifications, -1)

   return {success = true}
end

-- ##############################################

return syslog
