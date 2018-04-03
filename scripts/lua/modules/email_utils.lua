--
-- (C) 2018 - ntop.org
--

local email = {}

local function getEmailMessage(now_ts, from, to, subject, body)
  local now = os.date("%a, %d %b %Y %X", now_ts) -- E.g. "Tue, 3 Apr 2018 14:58:00"
  local msg_id = "<" .. now_ts .. "." .. os.clock() .. "@ntopng>"

  local lines = {
    "From: " .. from,
    "To: " .. to,
    "Subject: " .. subject,
    "Date: " ..  now,
    "Message-ID: " .. msg_id,
  }

  return table.concat(lines, "\r\n") .. "\r\n\r\n" .. body .. "\r\n"
end

function email.sendNotification(notif)
  if notif.action == "release" then
    -- Avoid sending release notifications
    return
  end

  local email_address = ntop.getPref("ntopng.prefs.alerts.email_address")
  local smtp_server = ntop.getPref("ntopng.prefs.alerts.smtp_server")

  if isEmptyString(email_address) or isEmptyString(smtp_server) then
    return false
  end

  local product = ntop.getInfo(false).product
  local subject = product .. " [" .. string.upper(notif.severity) .. "]: " .. alertTypeLabel(alertType(notif.type), true)
  local message_body = unescapeHtmlEntities(noHtml(notif.message))
  local from_to = email_address
  local message = getEmailMessage(os.time(), from_to, from_to, subject, message_body)

  return ntop.sendMail(from_to, from_to, message, smtp_server)
end

return email
