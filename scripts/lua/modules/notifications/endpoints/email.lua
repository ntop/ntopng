--
-- (C) 2017-24 - ntop.org
--

local email = {
   name = "Email",
   endpoint_params = {
      { param_name = "smtp_server" },
      { param_name = "email_sender"},
      { param_name = "smtp_port", optional = true },
      { param_name = "use_proxy", optional = true },
      { param_name = "smtp_username", optional = true },
      { param_name = "smtp_password", optional = true },
   },
   endpoint_template = {
      script_key = "email",
      template_name = "email_endpoint.template"
   },
   recipient_params = {
      { param_name = "email_recipient" },
      { param_name = "cc", optional = true },
   },
   recipient_template = {
      script_key = "email",
      template_name = "email_recipient.template"
   },
}

require "lua_utils"
local json = require("dkjson")
local alert_utils = require "alert_utils"
local format_utils = require "format_utils"
local debug_endpoint = false

email.EXPORT_FREQUENCY = 60
email.prio = 200

local MAX_ALERTS_PER_EMAIL = 100
local MAX_NUM_SEND_ATTEMPTS = 5
local NUM_ATTEMPTS_KEY = "ntopng.alerts.modules_notifications_queue.email.num_attemps"

if ntop.getPref("ntopng.prefs.debug_email") == "1" then
   debug_endpoint = true
end

-- ##############################################

-- @brief Returns the desided formatted output for recipient params
function email.format_recipient_params(recipient_params)
   return string.format("%s (%s)", recipient_params.email_recipient, email.name)
end

-- ##############################################

local function recipient2sendMessageSettings(recipient)
  local settings = {
    smtp_server = recipient.endpoint_conf.smtp_server,
    smtp_port = recipient.endpoint_conf.smtp_port,
    use_proxy = toboolean(recipient.endpoint_conf.use_proxy),
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
  local msg_id = "<" .. now_ts .. "." .. os.clock() .. "@ntopng>"

  local lines = {
    "From: " .. from,
    "To: " .. to,
    "Subject: " .. subject,
    "Date: " .. format_utils.formatEpochRFC2822(now_ts),
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
  local smtp_port = settings.smtp_port
  local use_proxy = settings.use_proxy
  local from = settings.from_addr:gsub(".*<(.*)>", "%1")
  local to = settings.to_addr:gsub(".*<(.*)>", "%1")
  local cc = settings.cc_addr:gsub(".*<(.*)>", "%1")
  local product = ntop.getInfo(false).product
  local info = ntop.getHostInformation()

  if not isEmptyString(subject) then
    subject = subject .. " - "
  else
    subject = ""
  end
  subject = subject .. product .. " @ " .. info.instance_name .. " (" .. info.ip .. ")"

  if not string.find(smtp_server, "://") then
    smtp_server = "smtp://" .. smtp_server
  end

  smtp_port = tonumber(smtp_port)
  if smtp_port and smtp_port > 0 then
    smtp_server = smtp_server .. ":"..smtp_port
  end

  local parts = string.split(to, "@")

  if #parts == 2 then
    local sender_domain = parts[2]
    smtp_server = smtp_server .. "/" .. sender_domain
  end

  local message = buildMessageHeader(os.time(), settings.from_addr, settings.to_addr, settings.cc_addr, subject, message_body)

  -- Pass nil username and password when auth is not required
  local username = nil
  local password = nil
  if not isEmptyString(settings.username) then username = settings.username end
  if not isEmptyString(settings.password) then password = settings.password end

  return ntop.sendMail(from, to, cc, message, smtp_server, username, password, use_proxy, debug_endpoint)
end

-- ##############################################

-- Dequeue alerts from a recipient queue for sending notifications
function email.dequeueRecipientAlerts(recipient, budget)
  local sent = 0
  local more_available = true
  local budget_used = 0

  local settings = recipient2sendMessageSettings(recipient)

  -- Dequeue alerts up to budget x MAX_ALERTS_PER_EMAIL
  -- Note: in this case budget is the number of email to send
  while budget_used <= budget and more_available do
    -- Dequeue MAX_ALERTS_PER_EMAIL notifications

    local notifications = {}

    local i = 0
    local total_len = 0
    while i < MAX_ALERTS_PER_EMAIL do
      local notification = ntop.recipient_dequeue(recipient.recipient_id)

      if notification then 

        if debug_endpoint then
           tprint("Email: dequeued notification")
           tprint(notification)
        end

        if alert_utils.filter_notification(notification, recipient.recipient_id) then

          local notif = json.decode(notification.alert)

          if debug_endpoint then
             tprint("Email: notification matched the filter")
          end

          notifications[#notifications + 1] = notif

          i = i + 1

          if not notif.score then
            -- Not an alert (e.g. report), send out
            goto send_out
          end

        end
      else
        break
      end
    end

    ::send_out::

    if not notifications or #notifications == 0 then
      more_available = false
      break
    end

    -- Prepare email

    -- Subject
    local subject = format_utils.formatSubject(notifications)

    -- Body
    local messages = {}
    for _, notif in ipairs(notifications) do
      messages[#messages + 1] = format_utils.formatMessage(notif, {show_entity = true, nohtml=false, nolabelhtml=true})
    end
    local message_body = table.concat(messages, "<br>")

    if debug_endpoint then tprint(message_body) end

    -- Send email
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
