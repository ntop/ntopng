--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

local webhook = {
   name = "Webhook",
   endpoint_params = {
      { param_name = "webhook_url" },
      { param_name = "webhook_sharedsecret", optional = true },
      { param_name = "webhook_username", optional = true },
      { param_name = "webhook_password", optional = true },
      -- TODO: configure severity (Errors, Errors and Warnings, All)
   },
   endpoint_template = {
      plugin_key = "webhook_alert_endpoint",
      template_name = "webhook_endpoint.template"
   },
   recipient_params = {
   },
   recipient_template = {
      plugin_key = "webhook_alert_endpoint",
      template_name = "webhook_recipient.template"
   },
}

webhook.EXPORT_FREQUENCY = 60
webhook.API_VERSION = "0.2"
webhook.REQUEST_TIMEOUT = 1
webhook.ITERATION_TIMEOUT = 3
webhook.prio = 400
local MAX_ALERTS_PER_REQUEST = 10

-- ##############################################

-- @brief Returns the desided formatted output for recipient params
function webhook.format_recipient_params(recipient_params)
   return string.format("(%s)", webhook.name)
end

-- ##############################################

local function recipient2sendMessageSettings(recipient)
  local settings = {
    url = recipient.endpoint_conf.webhook_url,
    sharedsecret = recipient.endpoint_conf.webhook_sharedsecret,
    username = recipient.endpoint_conf.webhook_username,
    password = recipient.endpoint_conf.webhook_password,
  }

  return settings
end

-- ##############################################

function webhook.sendMessage(alerts, settings)
  if isEmptyString(settings.url) then
    return false
  end

  local message = {
    version = webhook.API_VERSION,
    sharedsecret = settings.sharedsecret,
    alerts = alerts,
  }

  local json_message = json.encode(message)

  local rc = false
  local retry_attempts = 3
  while retry_attempts > 0 do
    if ntop.postHTTPJsonData(settings.username, settings.password, settings.url, json_message, webhook.REQUEST_TIMEOUT) then 
      rc = true
      break 
    end
    retry_attempts = retry_attempts - 1
  end

  return rc
end

-- ##############################################

function webhook.dequeueRecipientAlerts(recipient, budget, high_priority)
  local start_time = os.time()
  local sent = 0
  local more_available = true
  local budget_used = 0

  local settings = recipient2sendMessageSettings(recipient)

  -- Dequeue alerts up to budget x MAX_ALERTS_PER_REQUEST
  -- Note: in this case budget is the number of webhook messages to send
  while budget_used <= budget and more_available do

    local diff = os.time() - start_time
    if diff >= webhook.ITERATION_TIMEOUT then
      break
    end

    -- Dequeue MAX_ALERTS_PER_REQUEST notifications
    local notifications = {}
    for i = 1, MAX_ALERTS_PER_REQUEST do
       local notification = ntop.recipient_dequeue(recipient.recipient_id, high_priority)
       if notification then 
	  notifications[#notifications + 1] = notification
       else
	  break
       end
    end

    if not notifications or #notifications == 0 then
      more_available = false
      break
    end

    local alerts = {}

    for _, json_message in ipairs(notifications) do
      local alert = json.decode(json_message)
      table.insert(alerts, alert)
    end

    if not webhook.sendMessage(alerts, settings) then
      return {success=false, error_message="Unable to send alerts to the webhook"}
    end

    -- Remove the processed messages from the queue
    budget_used = budget_used + #notifications
    sent = sent + 1
  end

  return {success = true, more_available = more_available}
end

-- ##############################################

function webhook.runTest(recipient)
  local message_info

  local settings = recipient2sendMessageSettings(recipient)

  local success = webhook.sendMessage({}, settings)

  if success then
    message_info = i18n("prefs.webhook_sent_successfully")
  else
    message_info = i18n("prefs.webhook_send_error")
  end

  return success, message_info
end

-- ##############################################

return webhook

