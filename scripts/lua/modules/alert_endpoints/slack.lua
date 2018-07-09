--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

local slack = {}

slack.EXPORT_FREQUENCY = 60
local MAX_ALERTS_PER_MESSAGE = 5

local alert_severity_to_emoji = {
  ["info"] = ":information_source:",
  ["warning"] = ":warning:",
  ["error"] = ":exclamation:",

  default = ":warning:",
}

function slack.getChannelName(entity_type)
  local custom_chan = ntop.getHashCache("ntopng.prefs.alerts.slack_channels", entity_type)

  if not isEmptyString(custom_chan) then
    return custom_chan
  else
    return entity_type
  end
end

function slack.sendMessage(entity_type, severity, text)
  local channel_name = slack.getChannelName(entity_type)
  local webhook = ntop.getPref("ntopng.prefs.alerts.slack_webhook")
  local sender_username = ntop.getPref("ntopng.prefs.alerts.slack_sender_username")

  if isEmptyString(webhook) or isEmptyString(sender_username) then
    return false
  end

  local message = {
    channel = "#" .. channel_name,
    icon_emoji = alert_severity_to_emoji[severity] or alert_severity_to_emoji.default,
    username = sender_username .. " [" .. string.upper(severity)  .. "]",
    text = text,
  }

  local json_message = json.encode(message)
  return ntop.postHTTPJsonData("", "", webhook, json_message)
end

-- We will try to send the most recent MAX_ALERTS_PER_MESSAGE messages for every
-- channel and severity. On success, we clear the queue. On error, we leave the queue unchagned
-- to retry on next round.
function slack.dequeueAlerts(queue)
  local notifications = ntop.lrangeCache(queue, 0, -1)

  if not notifications then
    return {success=true}
  end

  -- Separate by severity and channel
  local alerts_by_types = {}

  for _, json_message in ipairs(notifications) do
    local notif = alertNotificationToObject(json_message)

    alerts_by_types[notif.entity_type] = alerts_by_types[notif.entity_type] or {}
    alerts_by_types[notif.entity_type][notif.severity] = alerts_by_types[notif.entity_type][notif.severity] or {}
    table.insert(alerts_by_types[notif.entity_type][notif.severity], notif)
  end

  for entity_type, by_severity in pairs(alerts_by_types) do
    for severity, notifications in pairs(by_severity) do
      local messages = {}

      -- Most recent notifications first
      for _, notif in pairsByValues(notifications, notification_timestamp_rev) do
        local msg = formatAlertNotification(notif, {nohtml=true, show_severity=false})
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

  -- Remove all the messages from queue on success
  ntop.delCache(queue)

  return {success=true}
end

return slack
