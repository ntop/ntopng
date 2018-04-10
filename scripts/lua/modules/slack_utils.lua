--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

local slack = {}

slack.EXPORT_FREQUENCY = 60

local alert_severity_to_emoji = {
  ["info"] = ":information_source:",
  ["warning"] = ":warning:",
  ["error"] = ":exclamation:",

  default = ":warning:",
}

function slack.sendMessage(channel_name, severity, text)
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

function slack.sendNotifications(notifications)
  -- Separate by severity and channel
  local alerts_by_types = {}

  for _, notif in ipairs(notifications) do
    alerts_by_types[notif.entity_type] = alerts_by_types[notif.entity_type] or {}
    alerts_by_types[notif.entity_type][notif.severity] = alerts_by_types[notif.entity_type][notif.severity] or {}
    table.insert(alerts_by_types[notif.entity_type][notif.severity], notif)
  end

  for entity_type, by_severity in pairs(alerts_by_types) do
    for severity, notifications in pairs(by_severity) do
      local messages = {}

      for _, notif in ipairs(notifications) do
        local msg = formatAlertNotification(notif, true, true)
        table.insert(messages, msg)
      end

      messages = table.concat(messages, "\n")

      if not slack.sendMessage(entity_type, severity, messages) then
        return false
      end
    end
  end

  return true
end

return slack
