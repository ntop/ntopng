--
-- (C) 2017-20 - ntop.org
--

local plugins_utils = require "plugins_utils"

local email = {
   name = "Email",
   endpoint_params = {
      { param_name = "smtp_server" },
      { param_name = "email_sender"},
      { param_name = "smtp_username", optional = true },
      { param_name = "smtp_password", optional = true },
   },
   endpoint_template = {
      plugin_key = "email_alert_endpoint",
      template_name = "email_endpoint.template"
   },
   recipient_params = {
      { param_name = "email_recipient" },
      { param_name = "cc", optional = true },
   },
   recipient_template = {
      plugin_key = "email_alert_endpoint",
      template_name = "email_recipient.template"
   },
}

local json = require("dkjson")
local alert_utils = require "alert_utils"
local debug_endpoint = false

email.EXPORT_FREQUENCY = 60
email.prio = 200

local MAX_ALERTS_PER_EMAIL = 100
local MAX_NUM_SEND_ATTEMPTS = 5
local NUM_ATTEMPTS_KEY = "ntopng.alerts.modules_notifications_queue.email.num_attemps"

-- ##############################################

-- @brief Returns the desided formatted output for recipient params
function email.format_recipient_params(recipient_params)
   return string.format("%s (%s)", recipient_params.email_recipient, email.name)
end

-- ##############################################

local function recipient2sendMessageSettings(recipient)
  local settings = {
    smtp_server = recipient.endpoint_conf.smtp_server,
    from_addr = recipient.endpoint_conf.email_sender,
    to_addr = recipient.recipient_params.email_recipient,
    cc_addr = recipient.recipient_params.cc,
    username = recipient.endpoint_conf.smtp_username,
    password = recipient.endpoint_conf.smtp_password,
  }

  return settings
end

-- ##############################################

local function buildMessageHeader(now_ts, from, to, cc, subject, body)
  local now = os.date("%a, %d %b %Y %X", now_ts) -- E.g. "Tue, 3 Apr 2018 14:58:00"
  local msg_id = "<" .. now_ts .. "." .. os.clock() .. "@ntopng>"

  local lines = {
    "From: " .. from,
    "To: " .. to,
    "Subject: " .. subject,
    "Date: " ..  now,
    "Message-ID: " .. msg_id,
    "Content-Type: text/html; charset=UTF-8",
  }

  if not isEmptyString(cc) then
     lines[#lines + 1] = "Cc: "..cc
  end

  return table.concat(lines, "\r\n") .. "\r\n\r\n" .. body .. "\r\n"
end

-- ##############################################

function email.isAvailable()
  return(ntop.sendMail ~= nil)
end

-- ##############################################

function email.sendEmail(subject, message_body, settings)
  local smtp_server = settings.smtp_server
  local from = settings.from_addr:gsub(".*<(.*)>", "%1")
  local to = settings.to_addr:gsub(".*<(.*)>", "%1")
  local cc = settings.cc_addr:gsub(".*<(.*)>", "%1")
  local product = ntop.getInfo(false).product
  local info = ntop.getHostInformation()

  subject = product .. " [" .. info.instance_name .. "@" .. info.ip .. "] " .. subject

  if not string.find(smtp_server, "://") then
    smtp_server = "smtp://" .. smtp_server
  end

  local parts = string.split(to, "@")

  if #parts == 2 then
    local sender_domain = parts[2]
    smtp_server = smtp_server .. "/" .. sender_domain
  end

  local message = buildMessageHeader(os.time(), settings.from_addr, settings.to_addr, settings.cc_addr, subject, message_body)
  return ntop.sendMail(from, to, cc, message, smtp_server, settings.username, settings.password)
end

-- ##############################################

-- Dequeue alerts from a recipient queue for sending notifications
function email.dequeueRecipientAlerts(recipient, budget, high_priority)
  local sent = 0
  local more_available = true
  local budget_used = 0

  -- Dequeue alerts up to budget x MAX_ALERTS_PER_EMAIL
  -- Note: in this case budget is the number of email to send
  while budget_used <= budget and more_available do
    -- Dequeue MAX_ALERTS_PER_EMAIL notifications

    local notifications = {}
    for i = 1, MAX_ALERTS_PER_EMAIL do
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

    -- Prepare email
    local subject = ""
    local message_body = {}

    if #notifications > 1 then
      subject = "(" .. i18n("alert_messages.x_alerts", {num=#notifications}) .. ")"
    end

    for _, json_message in ipairs(notifications) do
      local notif = json.decode(json_message)
      message_body[#message_body + 1] = alert_utils.formatAlertNotification(notif, {nohtml=true})
    end

    message_body = table.concat(message_body, "<br>")

    local settings = recipient2sendMessageSettings(recipient)

    -- Send email
    if debug_endpoint then tprint(message_body) end
    local rv = email.sendEmail(subject, message_body, settings)

    -- Handle retries on failure
    if not rv.success then
      local num_attemps = (tonumber(ntop.getCache(NUM_ATTEMPTS_KEY)) or 0) + 1

      if num_attemps >= MAX_NUM_SEND_ATTEMPTS then
        ntop.delCache(NUM_ATTEMPTS_KEY)
        return {success=false, error_message="Unable to send mails"}
      else
        ntop.setCache(NUM_ATTEMPTS_KEY, tostring(num_attemps))
        return {success=true}
      end
    else
      ntop.delCache(NUM_ATTEMPTS_KEY)
    end

    -- Remove the processed messages from the queue
    budget_used = budget_used + #notifications
    sent = sent + 1
  end

  return {success = true, more_available = more_available}
end

-- ##############################################

function email.runTest(recipient)
  local message_info

  local settings = recipient2sendMessageSettings(recipient)

  local sent = email.sendEmail("TEST MAIL", "Email notification is working", settings)

  if sent.success then
    message_info = i18n("prefs.email_sent_successfully")
  else
    message_info = i18n("prefs.email_send_error", {msg = sent.msg, url = "https://www.ntop.org/guides/ntopng/web_gui/alerts.html#email"})
  end

  return sent.success, message_info

end

-- ##############################################

return email
