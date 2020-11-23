--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"

local syslog = {
   name = "Syslog",
   conf_max_num = 1, -- At most 1 endpoint
   endpoint_params = {
      { param_name = "syslog_alert_format" },
      { param_name = "syslog_protocol", optional = true },
      { param_name = "syslog_host", optional = true },
      { param_name = "syslog_port", optional = true },
   },
   endpoint_template = {
      plugin_key = "syslog_alert_endpoint",
      template_name = "syslog_endpoint.template"
   },
   recipient_params = {
   },
   recipient_template = {
      plugin_key = "syslog_alert_endpoint",
      template_name = "syslog_recipient.template"
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

local function readSettings(recipient)
   local settings = {
      -- Endpoint
      protocol = recipient.endpoint_conf.syslog_protocol, -- tcp or udp
      host = recipient.endpoint_conf.syslog_host,
      port = recipient.endpoint_conf.syslog_port,
   }

   if isEmptyString(settings.host) then
      settings.host = nil
   else
      if settings.protocol == nil or settings.protocol ~= 'tcp' then
         settings.protocol = 'udp'
      end
      if settings.port == nil then
         settings.port = 514
      else
         settings.port = tonumber(settings.port)
      end
   end

   return settings
end

-- ##############################################

-- @brief Returns the desided formatted output for recipient params
function syslog.format_recipient_params(recipient_params)
   return string.format("(%s)", syslog.name)
end

-- ##############################################

function syslog.sendMessage(settings, notif, severity, syslog_format)
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
   elseif syslog_format and syslog_format == "ecs" then
     if ntop.isEnterpriseM() then
        package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
        local ecs_format = require "ecs_format"
        msg = json.encode(ecs_format.format(notif))
     else
        return false
     end
   else -- syslog_format == "plaintext"
      -- prepare a plaintext message
      msg = alert_utils.formatAlertNotification(notif, {
         nohtml = true,
	 show_severity = true,
	 show_entity = true})
   end

   if settings.host == nil then
      ntop.syslog(msg, syslog_severity)
   else
      local facility = 14 -- log alert
      local level = 1 -- alert (what about mapping severity?)
      local prio = (facility * 8) + level
      local date = format_utils.formatEpoch() -- "2020-11-09 18:00:00"
      local tag = "ntopng"
      local info = ntop.getInfo()
      local pid = info.pid

      -- Example 
      -- Example: <113>09/11/2020 18:31:21 ntopng[21365]: ...  
      msg = "<"..prio..">"..date.." "..tag.."["..pid.."]: "..msg

      if settings.protocol == 'tcp' then
         ntop.send_tcp_data(settings.host, settings.port, msg.."\n", 1 --[[ timeout (msec) --]] )
      else
         ntop.send_udp_data(settings.host, settings.port, msg)
      end
   end

   return true
end

-- ##############################################

-- Dequeue alerts from a recipient queue for sending notifications
function syslog.dequeueRecipientAlerts(recipient, budget, high_priority)   
   local settings = readSettings(recipient)

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
            syslog.sendMessage(settings, notif, severity, recipient.endpoint_conf.syslog_alert_format)
	 end
      end
   end

   return {success = true,  more_available = true}
end

-- ##############################################

function syslog.runTest(recipient)
   local settings = readSettings(recipient)

   local now = os.time()
   local notif = {
      alert_tstamp = now,
      alert_entity = alert_consts.alert_entities.test.entity_id,
   }

   local success = syslog.sendMessage(settings, notif, "info", recipient.endpoint_conf.syslog_alert_format)

   local message_info = i18n("prefs.syslog_sent_successfully")
   return success, message_info
end

-- ##############################################

return syslog
