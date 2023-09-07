--
-- (C) 2021 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"
local alert_severities = require "alert_severities"
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
      script_key = "syslog",
      template_name = "syslog_endpoint.template"
   },
   recipient_params = {
   },
   recipient_template = {
      script_key = "syslog",
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
      syslog_alert_format = recipient.endpoint_conf.syslog_alert_format
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

-- Convert day number according to RFC3164 (space instead of 0)
local function convertRFC3164Day(num)
  local n = tonumber(num)
  return string.format(ternary(n < 10, ' ', '') .. '%u', n)
end

-- ##############################################

function syslog.sendMessage(settings, notif, severity)
   local do_debug = false
   local syslog_severity = alert_consts.alertLevelToSyslogLevel(severity)
   local syslog_format = settings.syslog_alert_format
   local msg

   if syslog_format and syslog_format == "json" then
      -- Send it plain, notif is already a json-encoded string
      -- so for efficiency, no decoding is done
      msg = notif
   elseif syslog_format and syslog_format == "ecs" then
     if ntop.isEnterpriseM() then
        package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
        local ecs_format = require "ecs_format"
        msg = json.encode(ecs_format.format(json.decode(notif)))
     else
        return false
     end
   else -- syslog_format == "plaintext" or "plaintextrfc"
      -- prepare a plain text message
      msg = format_utils.formatMessage(json.decode(notif), {
         nohtml = true,
         show_severity = true,
         show_entity = true,
         timezone = true --[[ Epochs adjusted to the server TZ using ISO 8601 date format --]]
      })
   end

   if settings.host == nil then
      ntop.syslog(msg, syslog_severity)
   else

      local facility = 14 -- log alert
      local level = syslog_severity
      local prio = (facility * 8) + level
      local host_info = ntop.getHostInformation()
      local host = host_info.ip
      local tag = "ntopng"
      local info = ntop.getInfo()
      local pid = info.pid

      if syslog_format and syslog_format == "plaintextrfc" then
         local iso_time = format_utils.formatEpochISO8601() -- "2020-11-19T18:31:21.003Z" (UTC)

         -- RFC5424 Format:
         -- <PRIO>VERSION ISOTIMESTAMP HOSTNAME APPLICATION PID MESSAGEID MSG
         -- Example:
         -- <113>1 2020-11-19T18:31:21.003Z 192.168.1.1 ntopng 21365 ID1 -
         msg = "<"..prio..">1 "..iso_time.." "..host.." "..tag.." "..pid.." - - "..msg
      else
         local log_time = os.date("%b %d %X") -- "Feb 25 09:58:12" (localtime)
         --local log_time = os.date("!%b %d %X") -- "Feb 25 09:58:12" (UTC)

         local log_time_arr = split(log_time, ' ')
         local month = log_time_arr[1]
         local day = log_time_arr[2]
         local time = log_time_arr[3]

         -- Convert day according to RFC3164
         log_time = string.format("%s %s %s",
            month, convertRFC3164Day(day), time)

         -- Unix Format:
         -- <PRIO>DATE TIME DEVICE APPLICATION[PID]: MSG
         -- Example:
         -- <113>Feb 25 09:58:12 192.168.1.1 ntopng[21365]: ...
         msg = "<"..prio..">"..log_time.." "..host.." "..tag.."["..pid.."]: "..msg
      end

      local success = true
      if settings.protocol == 'tcp' then
         success = ntop.send_tcp_data(settings.host, settings.port, msg.."\n", 1 --[[ timeout (msec) --]] )
      else
         ntop.send_udp_data(settings.host, settings.port, msg)
      end

      if not success then
         if do_debug then
            tprint("[syslog] Failure delivering message")
         end
      end
   end

   return true
end

-- ##############################################

-- Dequeue alerts from a recipient queue for sending notifications
function syslog.dequeueRecipientAlerts(recipient, budget)
   local settings = readSettings(recipient)
   local notifications = {}

   local i = 0
    while i < budget do
      local notification = ntop.recipient_dequeue(recipient.recipient_id)
      if notification then 
        if alert_utils.filter_notification(notification, recipient.recipient_id) then
          notifications[#notifications + 1] = notification.alert
          i = i + 1
        end
      else
        break
      end
    end

   if not notifications or #notifications == 0 then
      return {success = true, more_available = false}
   end

   -- Most recent notifications first
   for _, notification in ipairs(notifications) do
      syslog.sendMessage(settings, notification.alert, map_score_to_severity(notification.score))
   end

   return {success = true,  more_available = true}
end

-- ##############################################

function syslog.runTest(recipient)
   local settings = readSettings(recipient)

   local now = os.time()
   local notif = {
      tstamp = now,
      entity_id = alert_consts.alert_entities.flow.entity_id,
      severity = alert_severities.info.severity_id
   }

   local success = syslog.sendMessage(settings, json.encode(notif), alert_severities.info.severity_id)

   local message_info = i18n("prefs.syslog_sent_successfully")
   return success, message_info
end

-- ##############################################

return syslog
