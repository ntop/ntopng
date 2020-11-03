--
-- (C) 2020 - ntop.org
--

--
-- This is the core plugin file where everything 
-- has birth
--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"

local endpoint_key = "discord_alert_endpoint"

local discord = {
   name = "Discord", -- A human readable name which will be shown in the UI

   -- (1) Endpoint (see https://birdie0.github.io/discord-webhooks-guide/tools/curl.html)
   endpoint_params = {
      -- Define here the endpoint parameters used in the endpoint GUI
      { param_name = "discord_url" },
   },
   
   endpoint_template = {
      plugin_key = endpoint_key, -- Unique string key

      -- Filename of the GUI block for this endpoint
      -- relative pathname to discord_alert_endpoint/templates/discord_endpoint.template
      template_name = "discord_endpoint.template" 
   },


   -- (2) Recipient
   recipient_params = {
      -- Define here the endpoint parameters used in the recipient GUI
      { param_name = "discord_username" }
   },
   recipient_template = {
      plugin_key = endpoint_key, -- Unique string key

      template_name = "discord_recipient.template"
   },
}

-- ##############################################

-- How often this script will be called (in seconds) for checking if there are messages to be processes
discord.EXPORT_FREQUENCY = 5

-- ##############################################

-- @brief Returns the desided formatted output for recipient params
function discord.format_recipient_params(recipient_params)
   return string.format("%s (%s)", recipient_params.discord_username, discord.name)
end

-- ##############################################

-- Extract settings from recipients and place them on a simple datastructure
local function readSettings(recipient)
   local settings = {
      -- Endpoint
     url = recipient.endpoint_conf.discord_url, -- this information is coming from the endpoint configuration recipient.endpoint_conf. ...
     -- Recipient
     discord_username = recipient.recipient_params.discord_username, -- (**) this information is coming from the recipient configuration recipient.recipient_params. ...
  }

  return settings
end

-- ##############################################

-- Function called whenever a message has to be sent out to discord
function discord.sendMessage(message_body, settings)
   local rc = false
   local retry_attempts = 3
   local username = settings.discord_username:gsub("%s+", "") -- Zap spaces

   if isEmptyString(settings.url) then
      return false
   end

   -- Discord usernames don't have spaces. This line of code will be removed when
   -- (***) will be solved and the input will be clean

   while retry_attempts > 0 do
      local message = {
	 username = username,
	 content  = message_body,
      }

      local msg = json.encode(message)
      local post_rc = ntop.httpPost(settings.url, msg)

      if post_rc then
	 if post_rc.RESPONSE_CODE == 204 then
	    -- Success
	    rc = true
	    break
	 elseif post_rc.RESPONSE_CODE == 429 then
	    -- Too many requests, don't retry as this would cause the situation to worsen
	    -- https://httpstatuses.com/429
	    return false, "Too many requests"
	 end
      end

      retry_attempts = retry_attempts - 1
   end

   return rc
end

-- ##############################################

local function formatDiscordMessage(alert)
   local msg = alert_utils.formatAlertNotification(alert, {nohtml=true, add_cr=true, no_bracket_around_date=true, emoji=true})
   
   return(msg)
end

-- ##############################################

-- Function called periodically to process queued alerts to be delivered via Discord
function discord.dequeueRecipientAlerts(recipient, budget, high_priority)
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
       table.insert(alerts, formatDiscordMessage(json.decode(json_message)))       
    end

    local res, msg = discord.sendMessage(table.concat(alerts, "\n"), settings)
    if not res then
      return {success = false, error_message = msg or "Unable to send alerts to Discord"}
    end

    -- Remove the processed messages from the queue
    budget_used = budget_used + #notifications
    sent = sent + 1
  end

  return {success = true, more_available = more_available}
end

-- ##############################################

-- This is a testing function invoked by the web GUI whenever a test message has to be sent out

function discord.runTest(recipient)
  local message_info

  local settings = readSettings(recipient)

  local success = discord.sendMessage("test", settings)

  if not success then
    message_info = i18n("discord_alert_endpoint.discord_send_error")
  end

  return success, message_info
end

-- ##############################################

return discord

