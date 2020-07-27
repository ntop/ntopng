--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

local webhook = {
   conf_params = {
      { param_name = "webhook_url" },
      { param_name = "webhook_sharedsecret", optional = true },
      { param_name = "webhook_username", optional = true },
      { param_name = "webhook_password", optional = true },
      -- TODO: configure severity (Errors, Errors and Warnings, All)
   },
   conf_template = {
      plugin_key = "webhook_alert_endpoint",
      template_name = "webhook_endpoint.template"
   },
   recipient_params = {
   },
   recipient_template = {
      plugin_key = "webhook_alert_endpoint",
      template_name = "webhook_recipient.template" -- TODO: add template
   },
}

webhook.EXPORT_FREQUENCY = 60
webhook.API_VERSION = "0.2"
webhook.REQUEST_TIMEOUT = 1
webhook.ITERATION_TIMEOUT = 3
webhook.prio = 400
local MAX_ALERTS_PER_REQUEST = 10

-- ##############################################

function webhook.sendMessage(alerts, settings)
  if isEmptyString(settings.url) then
    return false
  end

  local message = {
    version = webhook.API_VERSION,
    sharedsecret = settings.sharedsecret,
    alerts = alerts,
  }

  local json_message = json.encode(message)

  local rc = false
  local retry_attempts = 3
  while retry_attempts > 0 do
    if ntop.postHTTPJsonData(settings.username, settings.password, settings.url, json_message, webhook.REQUEST_TIMEOUT) then 
      rc = true
      break 
    end
    retry_attempts = retry_attempts - 1
  end

  return rc
end

-- ##############################################

function webhook.dequeueAlerts(queue)
  local start_time = os.time()

  local settings = {
    url = ntop.getPref("ntopng.prefs.alerts.webhook_url"),
    sharedsecret = ntop.getPref("ntopng.prefs.alerts.webhook_sharedsecret"),
    username = ntop.getPref("ntopng.prefs.alerts.webhook_username"),
    password = ntop.getPref("ntopng.prefs.alerts.webhook_password"),
  }

  local alerts = {}

  while true do

    local diff = os.time() - start_time
    if diff >= webhook.ITERATION_TIMEOUT then
      break
    end

    local json_alert = ntop.lpopCache(queue)

    if not json_alert then
      break
    end

    local alert = json.decode(json_alert)

    table.insert(alerts, alert)

    if #alerts >= MAX_ALERTS_PER_REQUEST then
      if not webhook.sendMessage(alerts, settings) then
        ntop.delCache(queue)
        return {success=false, error_message="Unable to send alerts to the webhook"}
      end
      alerts = {}
    end
  end

  if #alerts > 0 then
    if not webhook.sendMessage(alerts, settings) then
      ntop.delCache(queue)
      return {success=false, error_message="Unable to send alerts to the webhook"}
    end
  end

  return {success=true}
end

-- ##############################################

function webhook.dequeueRecipientAlerts(recipient, budget)
  local start_time = os.time()
  local sent = 0
  local more_available = true

  local settings = {
    url = recipient.endpoint_conf.endpoint_conf.webhook_url,
    sharedsecret = recipient.endpoint_conf.endpoint_conf.webhook_sharedsecret,
    username = recipient.endpoint_conf.endpoint_conf.webhook_username,
    password = recipient.endpoint_conf.endpoint_conf.webhook_password,
  }

  -- Dequeue alerts up to budget x MAX_ALERTS_PER_EMAIL
  -- Note: in this case budget is the number of email to send
  while sent < budget and more_available do

    local diff = os.time() - start_time
    if diff >= webhook.ITERATION_TIMEOUT then
      break
    end

    -- Dequeue MAX_ALERTS_PER_EMAIL notifications
    local notifications = ntop.lrangeCache(recipient.export_queue, 0, MAX_ALERTS_PER_REQUEST-1)

    if not notifications or #notifications == 0 then
      more_available = false
      break
    end

    local alerts = {}

    for _, json_message in ipairs(notifications) do
      local alert = json.decode(json_message)
      table.insert(alerts, alert)
    end

    if not webhook.sendMessage(alerts, settings) then
      ntop.delCache(recipient.export_queue)
      return {success=false, error_message="Unable to send alerts to the webhook"}
    end

    -- Remove the processed messages from the queue
    ntop.ltrimCache(recipient.export_queue, #notifications, -1)

    sent = sent + 1
  end

  return {success=true}
end

-- ##############################################

function webhook.handlePost()
  local message_info, message_severity

  if(_POST["send_test_webhook"] ~= nil) then

    local settings = {
      url = ntop.getPref("ntopng.prefs.alerts.webhook_url"),
      sharedsecret = ntop.getPref("ntopng.prefs.alerts.webhook_sharedsecret"),
      username = ntop.getPref("ntopng.prefs.alerts.webhook_username"),
      password = ntop.getPref("ntopng.prefs.alerts.webhook_password"),
    }

    local success = webhook.sendMessage({}, settings)

    if success then
       message_info = i18n("prefs.webhook_sent_successfully")
       message_severity = "alert-success"
    else
       message_info = i18n("prefs.webhook_send_error", {product=product})
       message_severity = "alert-danger"
    end
  end

  return message_info, message_severity
end

-- ##############################################

function webhook.printPrefs(alert_endpoints, subpage_active, showElements)
  print('<thead class="thead-light"><tr><th colspan="2" class="info">'..i18n("prefs.webhook_notification")..'</th></tr></thead>')

  local elementToSwitchWebhook = {"row_webhook_notification_severity_preference", "webhook_url", "webhook_sharedsecret", "webhook_test", "webhook_username", "webhook_password"}

  prefsToggleButton(subpage_active, {
    field = "toggle_webhook_notification",
    pref = alert_endpoints.getAlertNotificationModuleEnableKey("webhook", true),
    default = "0",
    disabled = showElements==false,
    to_switch = elementToSwitchWebhook,
  })

  local showWebhookNotificationPrefs = false
  if ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey("webhook")) == "1" then
     showWebhookNotificationPrefs = true
  else
     showWebhookNotificationPrefs = false
  end

  multipleTableButtonPrefs(subpage_active.entries["webhook_notification_severity_preference"].title, subpage_active.entries["webhook_notification_severity_preference"].description,
               alert_endpoints.getSeverityLabels(), alert_endpoints.getSeverityValues(), "error", "primary", "webhook_notification_severity_preference",
         alert_endpoints.getAlertNotificationModuleSeverityKey("webhook"), nil, nil, nil, nil, showElements and showWebhookNotificationPrefs)

  prefsInputFieldPrefs(subpage_active.entries["webhook_url"].title, subpage_active.entries["webhook_url"].description,
           "ntopng.prefs.alerts.", "webhook_url",
           "", nil, showElements and showWebhookNotificationPrefs, true, true, {attributes={spellcheck="false"}, style={width="43em"}, required=true, pattern=getURLPattern()})

  prefsInputFieldPrefs(subpage_active.entries["webhook_sharedsecret"].title, subpage_active.entries["webhook_sharedsecret"].description,
           "ntopng.prefs.alerts.", "webhook_sharedsecret",
           "", nil, showElements and showWebhookNotificationPrefs, false, nil, {attributes={spellcheck="false"}, required=false})

  prefsInputFieldPrefs(subpage_active.entries["webhook_username"].title, subpage_active.entries["webhook_username"].description,
	     "ntopng.prefs.alerts.", "webhook_username", 
             "", false, showElements and showWebhookNotificationPrefs, nil, nil,  {attributes={spellcheck="false"}, pattern="[^\\s]+", required=false})

  prefsInputFieldPrefs(subpage_active.entries["webhook_password"].title, subpage_active.entries["webhook_password"].description,
	     "ntopng.prefs.alerts.", "webhook_password", 
             "", "password", showElements and showWebhookNotificationPrefs, nil, nil,  {attributes={spellcheck="false"}, pattern="[^\\s]+", required=false})

  print('<tr id="webhook_test" style="' .. ternary(showWebhookNotificationPrefs, "", "display:none;").. '"><td><button class="btn btn-secondary disable-on-dirty" type="button" onclick="sendTestWebhook();" style="width:230px; float:left;">'..i18n("prefs.send_test_webhook")..'</button></td></tr>')

  print[[<script>
  function sendTestWebhook() {
    var params = {};

    params.send_test_webhook = "";
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

    var form = paramsToForm('<form method="post"></form>', params);
    form.appendTo('body').submit();
  }
</script>]]
end

-- ##############################################

return webhook

