--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

local slack = {}

local alert_severity_to_emoji = {
  ["info"] = ":information_source:",
  ["warning"] = ":warning:",
  ["error"] = ":exclamation:",

  default = ":warning:",
}

function slack.sendNotification(notif)
  local webhook = ntop.getPref("ntopng.prefs.alerts.slack_webhook")
  local sender_username = ntop.getPref("ntopng.prefs.alerts.slack_sender_username")
  local notification_sender = sender_username

  if isEmptyString(webhook) or isEmptyString(sender_username) then
    return false
  end

  local msg_prefix = alertNotificationActionToLabel(notif.action)

  local message = {
    channel = "#" .. notif.entity_type,
    icon_emoji = alert_severity_to_emoji[notif.severity] or alert_severity_to_emoji.default,
    username = sender_username .. " [" .. string.upper(notif.severity)  .. "]",
    text = noHtml(msg_prefix .. notif.message),
  }

  local json_message = json.encode(message)

  return ntop.postHTTPJsonData("", "", webhook, json_message)
end

return slack
