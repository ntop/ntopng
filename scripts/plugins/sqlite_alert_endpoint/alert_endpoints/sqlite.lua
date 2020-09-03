--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

local sqlite = {
   builtin = true, -- Whether this endpoint can be configured from the UI. Disabled for the builtin SQLite

   conf_params = {
      -- No params, SQLite is builtin
   },
   conf_template = {
      plugin_key = "sqlite_alert_endpoint",
      template_name = "sqlite_endpoint.template"
   },
   recipient_params = {
   },
   recipient_template = {
      plugin_key = "sqlite_alert_endpoint",
      template_name = "sqlite_recipient.template"
   },
}

sqlite.EXPORT_FREQUENCY = 1
sqlite.prio = 400

-- ##############################################

local function recipient2sendMessageSettings(recipient)
   local settings = {
      -- builtin
  }

   return settings
end

-- ##############################################

function sqlite.dequeueRecipientAlerts(recipient, budget)
  local start_time = os.time()
  local more_available = true
  local budget_used = 0

  -- Dequeue alerts up to budget x MAX_ALERTS_PER_REQUEST
  -- Note: in this case budget is the number of sqlite messages to send
  while budget_used <= budget and more_available do
    local notifications = ntop.lrangeCache(recipient.export_queue, 0, budget - 1)

    if not notifications or #notifications == 0 then
      more_available = false
      break
    end

    local alerts = {}

    for _, json_message in ipairs(notifications) do
      local alert = json.decode(json_message)
      table.insert(alerts, alert)
    end

    -- TODO: send

    -- Remove the processed messages from the queue
    ntop.ltrimCache(recipient.export_queue, #notifications, -1)
    budget_used = budget_used + #notifications
  end

  return {success = true, more_available = more_available}
end

-- ##############################################

function sqlite.runTest(recipient)
  return false, "Not implemented"
end

-- ##############################################

return sqlite
