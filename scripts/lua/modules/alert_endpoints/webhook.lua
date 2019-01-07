--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

local webhook = {}

webhook.EXPORT_FREQUENCY = 60
webhook.API_VERSION = "0.1"
local MAX_ALERTS_PER_REQUEST = 10

function webhook.sendMessage(alerts)
  local url = ntop.getPref("ntopng.prefs.alerts.webhook_url")
  local sharedsecret = ntop.getPref("ntopng.prefs.alerts.webhook_sharedsecret")
  local username = ntop.getPref("ntopng.prefs.alerts.webhook_username")
  local password = ntop.getPref("ntopng.prefs.alerts.webhook_password")

  if isEmptyString(url) then
    return false
  end

  local message = {
    version = webhook.API_VERSION,
    sharedsecret = sharedsecret,
    alerts = alerts,
  }

  local json_message = json.encode(message)

  return ntop.postHTTPJsonData(username, password, url, json_message)
end

function webhook.dequeueAlerts(queue)
  local alerts = {}

  while true do
    local json_alert = ntop.lpopCache(queue)

    if not json_alert then
      break
    end

    local alert = alertNotificationToObject(json_alert)

    table.insert(alerts, alert)

    if #alerts >= MAX_ALERTS_PER_REQUEST then
      if not webhook.sendMessage(alerts) then
        return {success=false, error_message="Unable to send alerts to the webhook"}
      end
      alerts = {}
    end
  end

  if #alerts > 0 then
    if not webhook.sendMessage(alerts) then
      return {success=false, error_message="Unable to send alerts to the webhook"}
    end
  end

  return {success=true}
end

return webhook

