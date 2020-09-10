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

local discord = {
   name = "Discord", -- A human readable name which will be shown in the UI

   -- (1) Endpoint (see https://birdie0.github.io/discord-webhooks-guide/tools/curl.html)
   conf_params = {
      -- Define here the endpoint parameters used in the endpoint GUI
      { param_name = "discord_url" },
   },
   
   conf_template = {
      plugin_key = "discord_alert_endpoint", -- Unique string key across plugins+endpoints

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
      plugin_key = "discord_alert_recipient", -- Unique string key across plugins+recipients

      template_name = "discord_recipient.template"
   },
}

-- Handle up to X queued messages per run
local MAX_ALERTS_PER_REQUEST = 10

-- How often this script will be called (in seconds) for checking if there are mesasges to be processes
discord.EXPORT_FREQUENCY = 5


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

      if ntop.httpPost(settings.url, msg) then 
	 rc = true
	 break 
      end
      
      retry_attempts = retry_attempts - 1
   end

   return rc
end

-- ##############################################

function discord.dequeueRecipientAlerts(recipient, budget, high_priority)
  local start_time = os.time()
  local sent = 0
  local more_available = true
  local budget_used = 0
  local settings = readSettings(recipient)

  -- Dequeue alerts up to budget x MAX_ALERTS_PER_REQUEST
  -- Note: in this case budget is the number of email to send
  while budget_used <= budget and more_available do
    local diff = os.time() - start_time
    if diff >= discord.ITERATION_TIMEOUT then
      break
    end

    -- Dequeue MAX_ALERTS_PER_REQUEST notifications
    local notifications = {}
    for i=1, MAX_ALERTS_PER_REQUEST do
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
      table.insert(alerts, alert_utils.formatAlertNotification(alert, {nohtml=true}))
    end

    if not discord.sendMessage(table.concat(alerts, "\n"), settings) then
      return {success=false, error_message="Unable to send alerts to the discord"}
    end

    -- Remove the processed messages from the queue
    budget_used = budget_used + #notifications
    sent = sent + 1
  end

  return {success = true, more_available = more_available}
end

-- ##############################################

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

