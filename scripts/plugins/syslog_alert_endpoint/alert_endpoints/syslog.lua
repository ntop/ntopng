--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"

local syslog = {
   conf_max_num = 1, -- At most 1 endpoint
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

-- syslog.DEFAULT_SEVERITY = "info"
syslog.EXPORT_FREQUENCY = 1 -- 1 second, i.e., as soon as possible
syslog.prio = 300

-- ##############################################

function syslog.isAvailable()
   return(ntop.syslog ~= nil)
end

-- ##############################################

function syslog.sendMessage(notif, severity, syslog_format)
   local syslog_severity = alert_consts.alertLevelToSyslogLevel(severity)
   local msg

   if syslog_format and syslog_format == "json" then
      -- send out the json message but prepare a nice
      -- message
      notif.message  = alert_utils.formatAlertNotification(notif, {
         nohtml = true,
	 show_severity = false,
	 show_entity = false})
      msg = json.encode(notif)
   else -- syslog_format == "plaintext"
      -- prepare a plaintext message
      msg = alert_utils.formatAlertNotification(notif, {
         nohtml = true,
	 show_severity = true,
	 show_entity = true})
   end

   ntop.syslog(msg, syslog_severity)

   return true
end

-- ##############################################

-- Dequeue alerts from a recipient queue for sending notifications
function syslog.dequeueRecipientAlerts(recipient, budget, high_priority)   
    local notifications = {}
    for i = 1, budget do
       local notification = ntop.recipient_dequeue(recipient.recipient_id, high_priority)
       if notification then 
	  notifications[#notifications + 1] = notification
       else
	  break
       end
    end

   if not notifications or #notifications == 0 then
      return {success = true, more_available = false}
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
            syslog.sendMessage(notif, severity, recipient.endpoint_conf.syslog_alert_format)
	 end
      end
   end

   return {success = true,  more_available = true}
end

-- ##############################################

function syslog.runTest(recipient)
  local now = os.time()
  local notif = {
    alert_tstamp = now,
    alert_entity = alert_consts.alert_entities.test.entity_id,
  }

  local success = syslog.sendMessage(notif, "info", recipient.endpoint_conf.syslog_alert_format)

  local message_info = i18n("prefs.syslog_sent_successfully")
  return success, message_info
end


-- ##############################################

return syslog
