--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

local webhook = {}

webhook.EXPORT_FREQUENCY = 60
webhook.API_VERSION = "0.2"
webhook.REQUEST_TIMEOUT = 1
webhook.ITERATION_TIMEOUT = 3
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

  local rc = false
  local retry_attempts = 3
  while retry_attempts > 0 do
    if ntop.postHTTPJsonData(username, password, url, json_message, webhook.REQUEST_TIMEOUT) then 
      rc = true
      break 
    end
    retry_attempts = retry_attempts - 1
  end

  return rc
end

function webhook.dequeueAlerts(queue)
  local start_time = os.time()

  local alerts = {}

  while true do

    local diff = os.time() - start_time
    if diff >= webhook.ITERATION_TIMEOUT then
      break
    end

    local json_alert = ntop.lpopCache(queue)

    if not json_alert then
      break
    end

    local alert = json.decode(json_alert)

    table.insert(alerts, alert)

    if #alerts >= MAX_ALERTS_PER_REQUEST then
      if not webhook.sendMessage(alerts) then
        ntop.delCache(queue)
        return {success=false, error_message="Unable to send alerts to the webhook"}
      end
      alerts = {}
    end
  end

  if #alerts > 0 then
    if not webhook.sendMessage(alerts) then
      ntop.delCache(queue)
      return {success=false, error_message="Unable to send alerts to the webhook"}
    end
  end

  return {success=true}
end

return webhook

