--
-- (C) 2021 - ntop.org
--

require "lua_utils"
local sys_utils = require "sys_utils"
local json = require "dkjson"
local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"

local endpoint_key = "shell_alert_endpoint"


local shell = {
    name = "Shell Script",
    endpoint_params = {
      { param_name = "shell_script" },
    },
    endpoint_template = {
      plugin_key = endpoint_key,
      template_name = "shell_endpoint.template"
    },
    recipient_params = {
    },
    recipient_template = {
      plugin_key = endpoint_key,
      template_name = "shell_recipient.template"
    },

    -- This is not a script that is supposed to run on Windows
    windows_exclude = true,
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
  }

  return settings
end

-- ##############################################

function shell.setup()
  local is_enabled = true

  global_state = {}

  return(is_enabled)
end

-- ##############################################

function shell.runScript(alerts, settings)
   local where = { "/usr/share/ntopng/scripts/shell/", dirs.installdir.."/scripts/shell/" }
   local fullpath = nil
   local do_debug = false
   
   for _,p in ipairs(where) do
      local path = p .. settings.path

      if(do_debug) then tprint("Checking "..path) end
      
      if(ntop.exists(path)) then
	 fullpath = path
	 break
      end
   end

   if(fullpath == nil) then
      if(do_debug) then tprint("Not found: "..settings.path.." ("..dirs.installdir ..")") end
      return(false)
   end

  for key, alert in ipairs(alerts) do
    -- Executing the script
    local exec_script = fullpath

    -- Mask output
    local cmd = exec_script .. " > /dev/null"

    -- Running script with the alert (json) as input (stdin)
    sys_utils.execShellCmd(cmd, json.encode(alert))

    -- Storing an alert-notice in regard of the shell script execution
    -- for security reasons
    local entity_info = alerts_api.systemEntity(ntop.getInfo().product)
    local type_info = alert_consts.alert_types.alert_shell_script_executed.new(
      exec_script,
      alert_consts.alertTypeLabel(alert["alert_id"], true)
    )
  
    type_info:set_score_notice()

    type_info:store(entity_info)
  end -- for

  return true
end

-- ##############################################

function shell.dequeueRecipientAlerts(recipient, budget, high_priority)
  local settings = recipient2sendMessageSettings(recipient)
  local start_time = os.time()
  local sent = 0
  local more_available = true
  local budget_used = 0
  local MAX_ALERTS_PER_REQUEST = 1
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
	  notifications[#notifications + 1] = notification.alert
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

    if(shell.runScript(alerts, settings) == false) then
       return { success=false, error_message="- unable to execute the script" }
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
  local success = shell.runScript({}, settings)

  if not success then
    message_info = i18n("shell_alert_endpoint.shell_send_error")
  end

  return success, message_info
end

-- ##############################################

return shell
