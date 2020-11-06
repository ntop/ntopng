--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

local endpoint_key = "shell_alert_endpoint"


local shell = {
    name = "Shell",
    endpoint_params = {
      { param_name = "shell_script" },
      -- TODO: configure severity (Errors, Errors and Warnings, All)
    },
    endpoint_template = {
      plugin_key = endpoint_key,
      template_name = "shell_endpoint.template"
    },
    recipient_params = {
      { param_name = "shell_options" },
    },
    recipient_template = {
      plugin_key = endpoint_key,
      template_name = "shell_recipient.template"
    },
}

shell.EXPORT_FREQUENCY = 5

-- ##############################################

-- @brief Returns the desided formatted output for recipient params
function shell.format_recipient_params(recipient_params)
   return string.format("(%s)", shell.name)
end

-- ##############################################

local function recipient2sendMessageSettings(recipient)
  local settings = {
    path    = recipient.endpoint_conf.shell_script,
    options = recipient.recipient_params.shell_options,
  }

  return settings
end

-- ##############################################

function shell.sendMessage(alerts, settings)

  if isEmptyString(settings.path) then
    return false
  end
  
  local msg = json.encode(alerts)

  local cmd = settings.path .. " " .. settings.options .. " " .. msg

  local tmp_file = io.popen(cmd .. ' \necho _$?')
  local tmp_read = tmp_file:read'*a'
  local exit_code = tmp_read:match'.*%D(%d+)'+0
  tmp_file:close()

  if(exit_code == 0) then
    return true
  end

  return false
end

-- ##############################################

function shell.dequeueRecipientAlerts(recipient, budget, high_priority)
  local start_time = os.time()
  local sent = 0
  local more_available = true
  local budget_used = 0
  local MAX_ALERTS_PER_REQUEST = 1

  local settings = recipient2sendMessageSettings(recipient)

  local return_msg = {}
  -- Dequeue alerts up to budget x MAX_ALERTS_PER_REQUEST
  -- Note: in this case budget is the number of script messages to send
  while budget_used <= budget and more_available do

    local diff = os.time() - start_time
    if diff >= shell.EXPORT_FREQUENCY then
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

    if not telegram.sendMessage(alerts, settings) then
      return {success=false, error_message="- unable to execute the script"}
    end

    -- Remove the processed messages from the queue
    budget_used = budget_used + #notifications
    sent = sent + 1
  end

  return {success = true, more_available = more_available}
end

-- ##############################################

function shell.runTest(recipient)
  local message_info

  local settings = recipient2sendMessageSettings(recipient)
  local success = shell.sendMessage({}, settings)

  if not success then
    message_info = i18n("shell_alert_endpoint.shell_send_error")
  end

  return success, message_info
end

-- ##############################################

return shell

