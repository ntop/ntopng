--
-- (C) 2021 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"


local webhook = {
  name = "Webhook",
  endpoint_params = {
    { param_name = "webhook_url" },
    { param_name = "webhook_sharedsecret", optional = true },
    { param_name = "webhook_username",     optional = true },
    { param_name = "webhook_password",     optional = true },
    -- TODO: configure severity (Errors, Errors and Warnings, All)
  },
  endpoint_template = {
    script_key = "webhook",
    template_name = "webhook_endpoint.template"
  },
  recipient_params = {
  },
  recipient_template = {
    script_key = "webhook",
    template_name = "webhook_recipient.template"
  },
}

webhook.EXPORT_FREQUENCY = 5
webhook.API_VERSION = "0.2"
webhook.REQUEST_TIMEOUT = 10
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
    timestamp = os.time(),
    sharedsecret = settings.sharedsecret,
    alerts = alerts,
  }

  -- Use dkjson with specific formatting options for consistency
  local json_message = json.encode(message, {
    indent = true, -- Pretty print
    keyorder = {   -- Consistent key ordering
      "version",
      "timestamp",
      "sharedsecret",
      "alerts"
    }
  })

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

local function formatAlertMsg(alert)
  local decoded_alert = json.decode(alert)
  if decoded_alert and decoded_alert.json then
    local json_decoded = json.decode(decoded_alert.json)

    -- Decode json (old format was string)
    if json_decoded and json_decoded.flow_risk_info and type(json_decoded.flow_risk_info) == "string" then
      json_decoded.flow_risk_info = json.decode(json_decoded.flow_risk_info)
    end
    if json_decoded and json_decoded.alert_generation and json_decoded.alert_generation.flow_risk_info and type(json_decoded.alert_generation.flow_risk_info) == "string" then
      json_decoded.alert_generation.flow_risk_info = json.decode(json_decoded.alert_generation.flow_risk_info)
    end

    decoded_alert.json = json_decoded
    decoded_alert.metadata = {}
  end
  return decoded_alert
end

-- ##############################################

function webhook.dequeueRecipientAlerts(recipient, budget)
  local start_time = os.time()
  local sent = 0
  local budget_used = 0
  local num_messages_dequeued = 0
  local debugme = false
  local settings = recipient2sendMessageSettings(recipient)

  local more_available = true
  local success = true
  local error_message = nil
  local delivered = 0
  local discarded = 0
  local failures = 0

  -- Dequeue alerts up to budget x MAX_ALERTS_PER_REQUEST
  -- Note: in this case budget is the number of webhook messages to send
  while budget_used <= budget and more_available do
    local diff = os.time() - start_time
    if diff >= webhook.ITERATION_TIMEOUT then
      break
    end

    -- Dequeue MAX_ALERTS_PER_REQUEST notifications
    local notifications = {}
    local i = 0
    while i < MAX_ALERTS_PER_REQUEST do
      local notification = ntop.recipient_dequeue(recipient.recipient_id)
      if notification then
        if alert_utils.filter_notification(notification, recipient.recipient_id) then
          notifications[#notifications + 1] = notification.alert
          i = i + 1
        else
          discarded = discarded + 1
        end
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
       local alert = formatAlertMsg(json_message)
       if(debugme) then tprint("[ALERT] "..json_message) end
       alerts[#alerts + 1] = alert
    end

    num_messages_dequeued = num_messages_dequeued + #notifications

    if(debugme) then tprint("[PARTIAL] Sending ".. #notifications .." messages out of "..i.." messages dequeued") end
    
    if not webhook.sendMessage(alerts, settings) then
       if(debugme) then tprint("[FAILURE] Message delivery failed") end
       success = false
       error_message = "Unable to send alerts to the webhook"
       failures = failures + #notifications
       goto done
    else
       if(debugme) then tprint("[OK] Message sent correctly") end
       delivered = delivered + #notifications
    end

    -- Remove the processed messages from the queue
    budget_used = budget_used + #notifications
    sent = sent + 1
  end

  if(debugme) then tprint("[END] Sent "..num_messages_dequeued.." messages") end
 
 ::done::
  return {
    success = success,
    error_message = error_message,
    delivered = delivered,
    discarded = discarded,
    failures  = failures,
    more_available = more_available,
  }
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
