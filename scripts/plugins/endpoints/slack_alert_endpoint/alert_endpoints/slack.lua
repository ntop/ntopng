--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_consts = require("alert_consts")
local alert_utils = require "alert_utils"

local slack = {
   name = "Slack",
   endpoint_params = {
      { param_name = "slack_sender_username" },
      { param_name = "slack_webhook" },
      -- TODO: add severity (Errors, Errors and Warnings, All)
   },
   endpoint_template = {
      plugin_key = "slack_alert_endpoint",
      template_name = "slack_endpoint.template"
   },
   recipient_params = {
      -- TODO: add channel
   },
   recipient_template = {
      plugin_key = "slack_alert_endpoint",
      template_name = "slack_recipient.template" -- TODO: add template
   },
}

slack.EXPORT_FREQUENCY = 60
slack.prio = 500
local MAX_ALERTS_PER_MESSAGE = 5

local alert_severity_to_emoji = {
  ["info"] = ":information_source:",
  ["warning"] = ":warning:",
  ["error"] = ":exclamation:",

  default = ":warning:",
}

-- ##############################################

-- @brief Returns the desided formatted output for recipient params
function slack.format_recipient_params(recipient_params)
   return string.format("(%s)", slack.name)
end

-- ##############################################

local function recipient2sendMessageSettings(recipient)
  local settings = {
    webhook = recipient.endpoint_conf.slack_webhook,
    sender_username = recipient.endpoint_conf.slack_sender_username,
  }

  return settings
end

-- ##############################################

function slack.sendMessage(entity_type, severity, text, settings)
  local channel_name = entity_type

  if isEmptyString(settings.webhook) or isEmptyString(settings.sender_username) then
    return false
  end

  local message = {
    channel = "#" .. channel_name,
    icon_emoji = alert_severity_to_emoji[severity] or alert_severity_to_emoji.default,
    username = settings.sender_username .. " [" .. string.upper(severity)  .. "]",
    text = text,
  }

  local json_message = json.encode(message)
  return ntop.postHTTPJsonData("", "", settings.webhook, json_message)
end

-- ##############################################

-- This will try to send the most recent MAX_ALERTS_PER_MESSAGE messages for every
-- channel and severity (no more than one message for each, budget is ignored). 
-- On success, it clears the queue.
-- On error, it leaves the queue unchagned to retry on next round.
function slack.dequeueRecipientAlerts(recipient, budget, high_priority)
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

  local settings = recipient2sendMessageSettings(recipient)

  -- Separate by severity and channel
  local alerts_by_types = {}

  for _, json_message in ipairs(notifications) do
    local notif = json.decode(json_message)
    if notif.alert_entity then
      if not alerts_by_types[notif.alert_entity] then
        alerts_by_types[notif.alert_entity] = {}
      end
      if not alerts_by_types[notif.alert_entity][notif.alert_severity] then
        alerts_by_types[notif.alert_entity][notif.alert_severity] = {}
      end
      table.insert(alerts_by_types[notif.alert_entity][notif.alert_severity], notif)
    end
  end

  for entity_type, by_severity in pairs(alerts_by_types) do
    for severity, notifications in pairs(by_severity) do
      local messages = {}
      entity_type = alert_consts.alertEntityRaw(entity_type)
      severity = alert_consts.alertSeverityRaw(severity)

      -- Most recent notifications first
      for _, notif in pairsByValues(notifications, alert_utils.notification_timestamp_rev) do
        local msg = alert_utils.formatAlertNotification(notif, {nohtml=true, show_severity=false})
        table.insert(messages, msg)

        if #messages >= MAX_ALERTS_PER_MESSAGE then
          break
        end
      end

      local missing = #notifications - #messages

      if missing > 0 then
        table.insert(messages, "NOTE: " .. missing .. " older messages have been suppressed")
      end

      messages = table.concat(messages, "\n")

      if not slack.sendMessage(entity_type, severity, messages) then
        -- Note: upon failure we'll possibly resend already sent messages
        return {success=false, error_message="Unable to send slack messages"}
      end
    end
  end

  return {success = true, more_available = true}
end

-- ##############################################

function slack.runTest(recipient)
  local message_info

  local settings = recipient2sendMessageSettings(recipient)

  local success = slack.sendMessage("interface", "info", "Slack notification is working", settings)

  if success then
    message_info = i18n("prefs.slack_sent_successfully", {channel="info"})
  else
    message_info = i18n("prefs.slack_send_error")
  end

  return success, message_info
end

-- ##############################################

return slack
