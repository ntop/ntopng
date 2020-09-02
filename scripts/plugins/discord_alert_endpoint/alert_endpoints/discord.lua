--
-- (C) 2020 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"

local discord = {
   -- Endpoint (see https://birdie0.github.io/discord-webhooks-guide/tools/curl.html)
   conf_params = {
      { param_name = "discord_url" },
   },
   conf_template = {
      plugin_key = "discord_alert_endpoint",
      template_name = "discord_endpoint.template"
   },
   -- Recipient
   recipient_params = {
      { param_name = "discord_username" }
   },
   recipient_template = {
      plugin_key = "discord_alert_endpoint",
      -- TODO: this parameter does not seem to be used (why?) and the field labels of (**) are mapped      
      --       in en.lua ["recipients"] = { ... ["discord_username"] = "Username", }
      -- (***)
      template_name = "discord_recipient.template"
   },
}

discord.EXPORT_FREQUENCY = 60
discord.API_VERSION = "0.2"
discord.REQUEST_TIMEOUT = 1
discord.ITERATION_TIMEOUT = 3
discord.prio = 400
local MAX_ALERTS_PER_REQUEST = 10

-- ##############################################

local function recipient2sendMessageSettings(recipient)
   local settings = {
      -- Endpoint
     url = recipient.endpoint_conf.endpoint_conf.discord_url,
     -- Recipient
     discord_username = recipient.recipient_params.discord_username, -- (**)
  }

  return settings
end

-- ##############################################

function discord.sendMessage(message_body, settings)
   if isEmptyString(settings.url) then
      return false
   end

   local rc = false
   local retry_attempts = 3
   local username = settings.discord_username:gsub("%s+", "") -- Zap spaces

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

function discord.dequeueRecipientAlerts(recipient, budget)
  local start_time = os.time()
  local sent = 0
  local more_available = true
  local budget_used = 0

  local settings = recipient2sendMessageSettings(recipient)

  -- Dequeue alerts up to budget x MAX_ALERTS_PER_REQUEST
  -- Note: in this case budget is the number of email to send
  while budget_used <= budget and more_available do
    local diff = os.time() - start_time
    if diff >= discord.ITERATION_TIMEOUT then
      break
    end

    -- Dequeue MAX_ALERTS_PER_REQUEST notifications
    local notifications = ntop.lrangeCache(recipient.export_queue, 0, MAX_ALERTS_PER_REQUEST- 1 )

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
      ntop.delCache(recipient.export_queue)
      return {success=false, error_message="Unable to send alerts to the discord"}
    end

    -- Remove the processed messages from the queue
    ntop.ltrimCache(recipient.export_queue, #notifications, -1)
    budget_used = budget_used + #notifications
    sent = sent + 1
  end

  return {success = true, more_available = more_available}
end

-- ##############################################

function discord.runTest(recipient)
  local message_info

  local settings = recipient2sendMessageSettings(recipient)

  local success = discord.sendMessage("test", settings)

  if success then
    message_info = i18n("prefs.discord_sent_successfully")
  else
    message_info = i18n("prefs.discord_send_error")
  end

  return success, message_info
end

-- ##############################################

return discord

