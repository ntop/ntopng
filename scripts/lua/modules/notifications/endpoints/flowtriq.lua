--
-- (C) 2024 - ntop.org
--
-- Flowtriq notification endpoint
-- Sends DDoS-related alerts to Flowtriq's inbound webhook API.
--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"

local endpoint_key = "flowtriq"

local flowtriq = {
   name = "Flowtriq",

   -- (1) Endpoint
   endpoint_params = {
      { param_name = "flowtriq_url" },
      { param_name = "flowtriq_api_key" },
   },
   endpoint_template = {
      script_key = endpoint_key,
      template_name = "flowtriq_endpoint.template"
   },

   -- (2) Recipient
   recipient_params = {
   },
   recipient_template = {
      script_key = endpoint_key,
      template_name = "flowtriq_recipient.template"
   },
}

flowtriq.EXPORT_FREQUENCY = 5
flowtriq.prio = 400
flowtriq.REQUEST_TIMEOUT = 10
flowtriq.ITERATION_TIMEOUT = 3
local MAX_ALERTS_PER_REQUEST = 10

-- ##############################################

-- @brief Returns the desired formatted output for recipient params
function flowtriq.format_recipient_params(recipient_params)
   return string.format("(%s)", flowtriq.name)
end

-- ##############################################

local function readSettings(recipient)
   local settings = {
      url = recipient.endpoint_conf.flowtriq_url,
      api_key = recipient.endpoint_conf.flowtriq_api_key,
   }

   return settings
end

-- ##############################################

local function formatAlertPayload(alert)
   local decoded_alert = json.decode(alert)

   if decoded_alert and decoded_alert.json then
      local json_decoded = json.decode(decoded_alert.json)

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

function flowtriq.sendMessage(alerts, settings)
   if isEmptyString(settings.url) or isEmptyString(settings.api_key) then
      return false
   end

   local message = {
      source = "ntopng",
      timestamp = os.time(),
      alerts = alerts,
   }

   local json_message = json.encode(message)

   local rc = false
   local retry_attempts = 3
   while retry_attempts > 0 do
      -- Use the bearer token (6th param) for API key authentication
      if ntop.postHTTPJsonData("", "", settings.url, json_message, flowtriq.REQUEST_TIMEOUT, settings.api_key) then
         rc = true
         break
      end
      retry_attempts = retry_attempts - 1
   end

   return rc
end

-- ##############################################

function flowtriq.dequeueRecipientAlerts(recipient, budget)
   local start_time = os.time()
   local sent = 0
   local budget_used = 0
   local settings = readSettings(recipient)

   local more_available = true
   local success = true
   local error_message = nil
   local delivered = 0
   local discarded = 0
   local failures = 0

   -- Dequeue alerts up to budget x MAX_ALERTS_PER_REQUEST
   while budget_used <= budget and more_available do
      local diff = os.time() - start_time
      if diff >= flowtriq.ITERATION_TIMEOUT then
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
         local alert = formatAlertPayload(json_message)
         table.insert(alerts, alert)
      end

      if not flowtriq.sendMessage(alerts, settings) then
         success = false
         error_message = "Unable to send alerts to Flowtriq"
         failures = failures + #notifications
         goto done
      else
         delivered = delivered + #notifications
      end

      -- Remove the processed messages from the queue
      budget_used = budget_used + #notifications
      sent = sent + 1
   end

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

function flowtriq.runTest(recipient)
   local message_info

   local settings = readSettings(recipient)

   local success = flowtriq.sendMessage({}, settings)

   if success then
      message_info = i18n("notification_endpoint.flowtriq.flowtriq_sent_successfully")
   else
      message_info = i18n("notification_endpoint.flowtriq.flowtriq_send_error")
   end

   return success, message_info
end

-- ##############################################

return flowtriq
