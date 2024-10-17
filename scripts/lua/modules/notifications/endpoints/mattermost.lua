require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"
local format_utils = require "format_utils"

local endpoint_key = "mattermost"

local mattermost = {
  name = "Mattermost",
  endpoint_params = {
    -- Define here the endpoint parameters used in the endpoint GUI
    { param_name = "mattermost_url" },
    { param_name = "mattermost_token" },
  },
  endpoint_template = {
    script_key = endpoint_key, -- Unique string key
    template_name = "mattermost_endpoint.template"
  },
  recipient_params = {
    { param_name = "mattermost_channelname" }
  },
  recipient_template = {
    script_key = endpoint_key,
    template_name = "mattermost_recipient.template"
  }
}

-- dequeueRecipientAlerts will be invoked every 60 seconds
mattermost.EXPORT_FREQUENCY = 60
mattermost.prio = 500

-- ##############################################

local function readSettings(recipient)
  local settings = {
    -- Endpoint
    url = recipient.endpoint_conf.mattermost_url,
    mattermost_token = recipient.endpoint_conf.mattermost_token,           -- this information is coming from the endpoint configuration recipient.endpoint_conf.
    -- Recipient
    mattermost_channel = recipient.recipient_params
    .mattermost_channelname                                                -- (**) this information is coming from the recipient configuration recipient.recipient_params.
  }
  return settings
end

-- ##############################################

function mattermost.isAvailable()
  -- ntop.httpPost is not available on some platforms (e.g. Windows),
  -- so on such platforms this endpoint should be disabled.
  return (ntop.postHTTPJsonData ~= nil)
end

-- ##############################################

-- This is a custom function defined public with the purpose of allowing
-- other code to call it.
function mattermost.sendMattermost(message_body, settings)
  local rc = false
  local retry_attempts = 3

  if (isEmptyString(settings.mattermost_channel) or isEmptyString(settings.mattermost_token) or isEmptyString(settings.url))
  then
    return rc
  end

  while retry_attempts > 0 do
    local msg = message_body
    local body = json.encode({ channel_id = settings.mattermost_channel, message = msg })
    if (body ~= nil)
    then
      -- Only if a custom alert is thrown this script will be run
      local post_rc = ntop.postHTTPJsonData("", "", settings.url, body, nil, settings.mattermost_token)
      if post_rc
      then
        -- Success
        rc = true
        break
      end

      retry_attempts = retry_attempts - 1
    end
  end


  return rc
end

local function formatMattermostMessage(alert)
  local msg = format_utils.formatMessage(alert,
    { nohtml = true, add_cr = true, no_bracket_around_date = true, emoji = true, show_entity = true })

  return (msg)
end

-- The function in charge of dequeuing alerts. Some code is boilerplate and
-- can be copied to new endpoints.
function mattermost.dequeueRecipientAlerts(recipient, budget)
  local start_time = os.time()
  local sent = 0
  local more_available = true
  local budget_used = 0
  local max_alerts_per_request = 1 -- collapse up to X alerts per request
  local settings = readSettings(recipient)
  -- Dequeue alerts up to budget x max_alerts_per_request
  -- Note: in this case budget is the number of email to send
  while budget_used <= budget and more_available do
    local diff = os.time() - start_time
    if diff >= 5 then
      break
    end

    -- Dequeue max_alerts_per_request notifications
    local notifications = {}
    local i = 0
    while i < max_alerts_per_request do
      local notification = ntop.recipient_dequeue(recipient.recipient_id)
      if notification then
        if alert_utils.filter_notification(notification, recipient.recipient_id) then
          notifications[#notifications + 1] = notification.alert
          i = i + 1
        end
      else
        break
      end
    end

    if #notifications == 0 then
      more_available = false
      break
    end

    local alerts = {}

    for _, json_message in ipairs(notifications) do
      table.insert(alerts, formatMattermostMessage(json.decode(json_message)))
    end

    local res, msg = mattermost.sendMattermost(table.concat(alerts, "\n"), settings)
    if not res then
      return { success = false, error_message = msg }
    end

    -- Remove the processed messages from the queue
    budget_used = budget_used + #notifications
    sent = sent + 1
  end

  return { success = true, more_available = more_available }
end

-- ##############################################

return mattermost
