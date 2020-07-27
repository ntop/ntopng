--
-- (C) 2017-20 - ntop.org
--

local plugins_utils = require "plugins_utils"

local email = {
   conf_params = {
      { param_name = "smtp_server" },
      { param_name = "email_sender"},
      { param_name = "smtp_username", optional = true },
      { param_name = "smtp_password", optional = true },
   },
   conf_template = {
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

email.EXPORT_FREQUENCY = 60
email.prio = 200

local MAX_ALERTS_PER_EMAIL = 100
local MAX_NUM_SEND_ATTEMPTS = 5
local NUM_ATTEMPTS_KEY = "ntopng.alerts.modules_notifications_queue.email.num_attemps"

-- ##############################################

local function buildMessageHeader(now_ts, from, to, subject, body)
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

  return table.concat(lines, "\r\n") .. "\r\n\r\n" .. body .. "\r\n"
end

-- ##############################################

function email.isAvailable()
  return(ntop.sendMail ~= nil)
end

-- ##############################################

function email.sendEmail(subject, message_body, settings)
  if isEmptyString(settings.from_addr) or 
     isEmptyString(settings.to_addr) or 
     isEmptyString(settings.smtp_server) then
    return false
  end

  local smtp_server = settings.smtp_server
  local from = settings.from_addr:gsub(".*<(.*)>", "%1")
  local to = settings.to_addr:gsub(".*<(.*)>", "%1")
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

  local message = buildMessageHeader(os.time(), settings.from_addr, settings.to_addr, subject, message_body)
  return ntop.sendMail(from, to, message, smtp_server, settings.username, settings.password)
end

-- ##############################################

-- Deprecated
function email.dequeueAlerts(queue)
  local settings = {
    smtp_server = ntop.getPref("ntopng.prefs.alerts.smtp_server"),
    from_addr = ntop.getPref("ntopng.prefs.alerts.email_sender"),
    to_addr = ntop.getPref("ntopng.prefs.alerts.email_recipient"),
    username = ntop.getPref("ntopng.prefs.alerts.smtp_username"),
    password = ntop.getPref("ntopng.prefs.alerts.smtp_password"),
  }

  while true do
    local notifications = ntop.lrangeCache(queue, 0, MAX_ALERTS_PER_EMAIL-1)

    if not notifications then
      break
    end

    local subject = ""

    if #notifications > 1 then
      subject = "(" .. i18n("alert_messages.x_alerts", {num=#notifications}) .. ")"
    end

    local message_body = {}

    -- Multiple notifications
    for _, json_message in ipairs(notifications) do
      local notif = json.decode(json_message)
      message_body[#message_body + 1] = alert_utils.formatAlertNotification(notif, {nohtml=true})
    end

    message_body = table.concat(message_body, "<br>")

    local rv = email.sendEmail(subject, message_body, settings)

    if not rv then
      local num_attemps = (tonumber(ntop.getCache(NUM_ATTEMPTS_KEY)) or 0) + 1

      if num_attemps >= MAX_NUM_SEND_ATTEMPTS then
        ntop.delCache(NUM_ATTEMPTS_KEY)
        -- Prevent alerts starvation if the plugin is not working after max num attempts
        ntop.delCache(queue)
        return {success=false, error_message="Unable to send mails"}
      else
        ntop.setCache(NUM_ATTEMPTS_KEY, tostring(num_attemps))
        return {success=true}
      end
    else
      ntop.delCache(NUM_ATTEMPTS_KEY)
    end

    -- Remove the processed messages from the queue
    ntop.ltrimCache(queue, MAX_ALERTS_PER_EMAIL, -1)
  end

  return {success=true}
end

-- ##############################################

-- Dequeue alerts from a recipient queue for sending notifications
function email.dequeueRecipientAlerts(recipient, budget)
  local sent = 0
  local more_available = true

  -- Dequeue alerts up to budget x MAX_ALERTS_PER_EMAIL
  -- Note: in this case budget is the number of email to send
  while sent < budget and more_available do
    
    -- Dequeue MAX_ALERTS_PER_EMAIL notifications
    local notifications = ntop.lrangeCache(recipient.export_queue, 0, MAX_ALERTS_PER_EMAIL-1)

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

    local settings = {
      smtp_server = recipient.endpoint_conf.endpoint_conf.smtp_server,
      from_addr = recipient.endpoint_conf.endpoint_conf.email_sender,
      to_addr = recipient.recipient_params.email_recipient,
      username = recipient.endpoint_conf.endpoint_conf.smtp_username,
      password = recipient.endpoint_conf.endpoint_conf.smtp_password,
    }

    -- Send email
    local rv = email.sendEmail(subject, message_body, settings)

    -- Handle retries on failure
    if not rv then
      local num_attemps = (tonumber(ntop.getCache(NUM_ATTEMPTS_KEY)) or 0) + 1

      if num_attemps >= MAX_NUM_SEND_ATTEMPTS then
        ntop.delCache(NUM_ATTEMPTS_KEY)
        -- Prevent alerts starvation if the plugin is not working after max num attempts
        ntop.delCache(recipient.export_queue)
        return {success=false, error_message="Unable to send mails"}
      else
        ntop.setCache(NUM_ATTEMPTS_KEY, tostring(num_attemps))
        return {success=true}
      end
    else
      ntop.delCache(NUM_ATTEMPTS_KEY)
    end

    -- Remove the processed messages from the queue
    ntop.ltrimCache(recipient.export_queue, #notifications, -1)

    sent = sent + 1
  end

  return {success=true}
end

-- ##############################################

function email.handlePost()
  local message_info, message_severity

  if(_POST["email_sender"] ~= nil) then
    _POST["email_sender"] = unescapeHTML(_POST["email_sender"])
  end

  if(_POST["email_recipient"] ~= nil) then
    _POST["email_recipient"] = unescapeHTML(_POST["email_recipient"])
  end

  if(_POST["send_test_email"] ~= nil) then
    local settings = {
      smtp_server = ntop.getPref("ntopng.prefs.alerts.smtp_server"),
      from_addr = ntop.getPref("ntopng.prefs.alerts.email_sender"),
      to_addr = ntop.getPref("ntopng.prefs.alerts.email_recipient"),
      username = ntop.getPref("ntopng.prefs.alerts.smtp_username"),
      password = ntop.getPref("ntopng.prefs.alerts.smtp_password"),
    }

    local success = email.sendEmail("TEST MAIL", "Email notification is working", settings)

    if success then
       message_info = i18n("prefs.email_sent_successfully")
       message_severity = "alert-success"
    else
       message_info = i18n("prefs.email_send_error", {url="https://www.ntop.org/guides/ntopng/web_gui/alerts.html#email"})
       message_severity = "alert-danger"
    end
  end

  return message_info, message_severity
end

-- ##############################################

function email.printPrefs(alert_endpoints, subpage_active, showElements)
  print('<thead class="thead-light"><tr><th colspan="2" class="info">'..i18n("prefs.email_notification")..'</th></tr></thead>')
  
  local elementToSwitch = {"row_email_notification_severity_preference", "email_sender", "email_recipient", "smtp_server", "smtp_username", "smtp_password", "alerts_test"}

  prefsToggleButton(subpage_active, {
        field = "toggle_email_notification",
        pref = alert_endpoints.getAlertNotificationModuleEnableKey("email", true),
        default = "0",
        disabled = (showElements==false),
        to_switch = elementToSwitch,
  })

  local showEmailNotificationPrefs = false
  if ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey("email")) == "1" then
     showEmailNotificationPrefs = true
  else
     showEmailNotificationPrefs = false
  end

  multipleTableButtonPrefs(subpage_active.entries["notification_severity_preference"].title, subpage_active.entries["notification_severity_preference"].description,
         alert_endpoints.getSeverityLabels(), alert_endpoints.getSeverityValues(), "error", "primary", "email_notification_severity_preference",
         alert_endpoints.getAlertNotificationModuleSeverityKey("email"), nil, nil, nil, nil, showElements and showEmailNotificationPrefs)

  prefsInputFieldPrefs(subpage_active.entries["email_notification_server"].title, subpage_active.entries["email_notification_server"].description,
           "ntopng.prefs.alerts.", "smtp_server",
           "", nil, showElements and showEmailNotificationPrefs, false, true, {attributes={spellcheck="false"}, required=true, pattern="^((smtp://)|(smtps://))?[a-zA-Z0-9-.]*(:[0-9]+)?$"})

  prefsInputFieldPrefs(subpage_active.entries["email_notification_username"].title, subpage_active.entries["email_notification_username"].description,
           "ntopng.prefs.alerts.", "smtp_username",
           "", nil, showElements and showEmailNotificationPrefs, false, nil, {attributes={spellcheck="false"}, required=false})

  prefsInputFieldPrefs(subpage_active.entries["email_notification_password"].title, subpage_active.entries["email_notification_password"].description,
           "ntopng.prefs.alerts.", "smtp_password",
           "", "password", showElements and showEmailNotificationPrefs, false, nil, {attributes={spellcheck="false"}, required=false})

  prefsInputFieldPrefs(subpage_active.entries["email_notification_sender"].title, subpage_active.entries["email_notification_sender"].description,
           "ntopng.prefs.alerts.", "email_sender",
           "", nil, showElements and showEmailNotificationPrefs, false, nil, {attributes={spellcheck="false"}, pattern=email_peer_pattern, required=true})

  prefsInputFieldPrefs(subpage_active.entries["email_notification_recipient"].title, subpage_active.entries["email_notification_recipient"].description,
           "ntopng.prefs.alerts.", "email_recipient",
           "", nil, showElements and showEmailNotificationPrefs, false, nil, {attributes={spellcheck="false"}, pattern=email_peer_pattern, required=true})

  print('<tr id="alerts_test" style="' .. ternary(showEmailNotificationPrefs, "", "display:none;").. '"><td><button class="btn btn-secondary disable-on-dirty" type="button" onclick="sendTestEmail();" style="width:230px; float:left;">'..i18n("prefs.send_test_mail")..'</button></td></tr>')

  print[[
<script>
  function sendTestEmail() {
      var params = {};

      params.send_test_email = "";
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

      var form = paramsToForm('<form method="post"></form>', params);
      form.appendTo('body').submit();
    }

    function replace_email_special_characters(event) {
      var form = $(this);

      // e.g. when form is invalid
      if(event.isDefaultPrevented())
        return;

      // this is necessary to escape "<" and ">" which are blocked on the backend to prevent injection
      $("[name='email_sender'],[name='email_recipient']", form).each(function() {
        var name = $(this).attr("name");
        $(this).removeAttr("name");

        $('<input type="hidden" name="' + name + '">')
          .val(encodeURI($(this).val()))
          .appendTo(form);
      });
    }

    $(function() {
      $("#external_alerts_form").submit(replace_email_special_characters);
    });
</script>]]
end

-- ##############################################

return email
