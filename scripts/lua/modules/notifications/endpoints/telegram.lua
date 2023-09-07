--
-- (C) 2020 - ntop.org
--
--
require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"
local format_utils = require "format_utils"

local endpoint_key = "telegram"

local telegram = {
    name = "Telegram", -- A human readable name which will be shown in the UI

    -- (1) Endpoint (see )
    endpoint_params = { -- Define here the endpoint parameters used in the endpoint GUI
    {
        param_name = "telegram_token"
    } -- Telegram token
    },

    endpoint_template = {
        script_key = endpoint_key, -- Unique string key

        -- Filename of the GUI block for this endpoint
        -- relative pathname to httpdocs/templates/page/notifications/telegram/telegram_endpoint.template
        template_name = "telegram_endpoint.template"
    },

    -- (2) Recipient
    recipient_params = { -- Define here the endpoint parameters used in the recipient GUI
    {
        param_name = "telegram_channel"
    } -- Name of the channel
    },
    recipient_template = {
        script_key = endpoint_key, -- Unique string key

        template_name = "telegram_recipient.template"
    }
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
        url = "https://api.telegram.org/bot" .. recipient.endpoint_conf.telegram_token .. "/sendMessage"
    }

    return settings
end

-- ##############################################

-- Function called whenever a message has to be sent out to telegram
function telegram.sendMessage(recipient, message_body, settings)
    local rc = false
    local retry_attempts = 3

    if isEmptyString(settings.url) then
        return false
    end

    while retry_attempts > 0 do

        tmp, tmp2 = string.match(message_body, "(.*) %[Info(.*)")

        if tmp == nil then
            tmp = message_body
        end

        local message = {
            chat_id = recipient.recipient_params.telegram_channel,
            text = tmp,
            disable_notification = true
        }

        local data = json.encode(message)

        -- In this case "httpPost" method is needed
        local post_rc = ntop.httpPost(settings.url, data)

        if (post_rc and (post_rc.RESPONSE_CODE == 200)) then
            rc = true
            break
        end

        retry_attempts = retry_attempts - 1
    end

    return rc
end

-- ##############################################

local function formatTelegramMessage(alert)
    local msg = format_utils.formatMessage(alert, {
        nohtml = true,
        add_cr = false,
        no_bracket_around_date = true,
        emoji = true,
        nodate = true,
        show_entity = true
    })

    return (msg)
end

-- ##############################################

-- Function called periodically to process queued alerts to be delivered via telegram
function telegram.dequeueRecipientAlerts(recipient, budget)
    local start_time = os.time()
    local sent = 0
    local more_available = true
    local budget_used = 0
    local settings = readSettings(recipient)
    local max_alerts_per_request = 1 -- collapse up to X alerts per request
    local alert_consts = require "alert_consts"

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

        if not notifications or #notifications == 0 then
            more_available = false
            break
        end

        local alerts = {}

        for _, json_message in ipairs(notifications) do
            table.insert(alerts, formatTelegramMessage(json.decode(json_message)))
        end

        local json_msg = table.concat(alerts, " | ")

        if not telegram.sendMessage(recipient, json_msg, settings) then
            return {
                success = false,
                error_message = "- unable to send alerts to the telegram"
            }
        end

        -- Remove the processed messages from the queue
        budget_used = budget_used + #notifications
        sent = sent + 1
    end

    return {
        success = true,
        more_available = more_available
    }
end

-- ##############################################

-- This is a testing function invoked by the web GUI whenever a test message has to be sent out

function telegram.runTest(recipient)
    local message_info

    local settings = readSettings(recipient)

    local success = telegram.sendMessage(recipient, "test", settings)

    if not success then
        message_info = i18n("telegram_alert_endpoint.telegram_send_error")
    end

    return success, message_info
end

-- ##############################################

return telegram

