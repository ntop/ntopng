--
-- (C) 2020-21 - ntop.org
--

--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"

local endpoint_key = "telegram_alert_endpoint"

local telegram = {
   name = "Telegram", -- A human readable name which will be shown in the UI

   -- (1) Endpoint (see )
   endpoint_params = {
      -- Define here the endpoint parameters used in the endpoint GUI
      { param_name = "token" }, -- Telegram token
   },
   
   endpoint_template = {
      plugin_key = endpoint_key, -- Unique string key

      -- Filename of the GUI block for this endpoint
      -- relative pathname to telegram_alert_endpoint/templates/telegram_endpoint.template
      template_name = "telegram_endpoint.template" 
   },


   -- (2) Recipient
   recipient_params = {
      -- Define here the endpoint parameters used in the recipient GUI
      { param_name = "channel_name"}, -- Name of the channel
   },
   recipient_template = {
      plugin_key = endpoint_key, -- Unique string key

      template_name = "telegram_recipient.template"
   },
}

-- ##############################################

-- How often this script will be called (in seconds) for checking if there are messages to be processes
telegram.EXPORT_FREQUENCY = 5

-- ##############################################

-- @brief Returns the desided formatted output for recipient params
function telegram.format_recipient_params(recipient_params)
   return string.format("(%s)", telegram.name)
end

-- ##############################################

-- Extract settings from recipients and place them on a simple datastructure
local function readSettings(recipient)
   local settings = {
      -- Endpoint
     url = "https://api.telegram.org/bot" .. recipient.endpoint_params.token .. "/sendMessage?chat_id=" .. recipient.recipient_params.channel_name .. "&text=", -- this information is coming from the endpoint configuration recipient.endpoint_conf. ...
  }

  return settings
end

-- ##############################################

-- Function called whenever a message has to be sent out to telegram
function telegram.sendMessage(message_body, settings)
   local rc = false
   local retry_attempts = 3

   if isEmptyString(settings.url) then
      return false
   end

   while retry_attempts > 0 do
--      local message = {
--	 content  = message_body,
--      }

      -- local msg = json.encode(message)

      -- Found Get way method to send messages, need to check if it's possible with Post method

      local post_rc = ntop.httpGet(settings.url .. message_body)

      if(post_rc and (post_rc.RESPONSE_CODE == 204)) then 
	 rc = true
	 break 
      end
      
      retry_attempts = retry_attempts - 1
   end

   return rc
end

-- ##############################################

local function formatTelegramMessage(alert)
   local msg = alert_utils.formatAlertNotification(alert, {nohtml=true, add_cr=true, no_bracket_around_date=true})
   
   return(msg)
end

-- ##############################################

-- Function called periodically to process queued alerts to be delivered via telegram
function telegram.dequeueRecipientAlerts(recipient, budget, high_priority)
  local start_time = os.time()
  local sent = 0
  local more_available = true
  local budget_used = 0
  local settings = readSettings(recipient)
  local max_alerts_per_request = 1 -- collapse up to X alerts per request

  -- Dequeue alerts up to budget x max_alerts_per_request
  -- Note: in this case budget is the number of email to send
  while budget_used <= budget and more_available do
    local diff = os.time() - start_time
    if diff >= 5 then
      break
    end

    -- Dequeue max_alerts_per_request notifications
    local notifications = {}
    for i=1, max_alerts_per_request do
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
       table.insert(alerts, formatTelegramMessage(json.decode(json_message)))       
    end

    if not telegram.sendMessage(table.concat(alerts, "\n"), settings) then
      return {success=false, error_message="Unable to send alerts to the telegram"}
    end

    -- Remove the processed messages from the queue
    budget_used = budget_used + #notifications
    sent = sent + 1
  end

  return {success = true, more_available = more_available}
end

-- ##############################################

-- This is a testing function invoked by the web GUI whenever a test message has to be sent out

function telegram.runTest(recipient)
  local message_info

  local settings = readSettings(recipient)

  local success = telegram.sendMessage("test", settings)

  if not success then
    message_info = i18n("telegram_alert_endpoint.telegram_send_error")
  end

  return success, message_info
end

-- ##############################################

return telegram

