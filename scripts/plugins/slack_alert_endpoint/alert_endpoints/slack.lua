--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_consts = require("alert_consts")
local alert_utils = require "alert_utils"

local slack = {}

slack.EXPORT_FREQUENCY = 60
slack.prio = 500
local MAX_ALERTS_PER_MESSAGE = 5

local alert_severity_to_emoji = {
  ["info"] = ":information_source:",
  ["warning"] = ":warning:",
  ["error"] = ":exclamation:",

  default = ":warning:",
}

-- ##############################################

function slack.getChannelName(entity_type)
  local custom_chan = ntop.getHashCache("ntopng.prefs.alerts.slack_channels", entity_type)

  if not isEmptyString(custom_chan) then
    return custom_chan
  else
    return entity_type
  end
end

-- ##############################################

function slack.sendMessage(entity_type, severity, text)
  local channel_name = slack.getChannelName(entity_type)
  local webhook = ntop.getPref("ntopng.prefs.alerts.slack_webhook")
  local sender_username = ntop.getPref("ntopng.prefs.alerts.slack_sender_username")

  if isEmptyString(webhook) or isEmptyString(sender_username) then
    return false
  end

  local message = {
    channel = "#" .. channel_name,
    icon_emoji = alert_severity_to_emoji[severity] or alert_severity_to_emoji.default,
    username = sender_username .. " [" .. string.upper(severity)  .. "]",
    text = text,
  }

  local json_message = json.encode(message)
  return ntop.postHTTPJsonData("", "", webhook, json_message)
end

-- ##############################################

-- We will try to send the most recent MAX_ALERTS_PER_MESSAGE messages for every
-- channel and severity. On success, we clear the queue. On error, we leave the queue unchagned
-- to retry on next round.
function slack.dequeueAlerts(queue)
  local notifications = ntop.lrangeCache(queue, 0, -1)

  if not notifications then
    return {success=true}
  end

  -- Separate by severity and channel
  local alerts_by_types = {}

  for _, json_message in ipairs(notifications) do
    local notif = json.decode(json_message)
    if notif.alert_entity then
      alerts_by_types[notif.alert_entity] = alerts_by_types[notif.alert_entity] or {}
      alerts_by_types[notif.alert_entity][notif.alert_severity] = alerts_by_types[notif.alert_entity][notif.alert_severity] or {}
      table.insert(alerts_by_types[notif.alert_entity][notif.alert_severity], notif)
    end
  end

  for entity_type, by_severity in pairs(alerts_by_types) do
    for severity, notifications in pairs(by_severity) do
      local messages = {}
      entity_type = alert_consts.alertEntityRaw(entity_type)
      severity = alert_consts.alertSeverityRaw(severity)

      -- Most recent notifications first
      for _, notif in pairsByValues(notifications, alert_utils.notification_timestamp_rev) do
        local msg = alert_utils.formatAlertNotification(notif, {nohtml=true, show_severity=false})
        table.insert(messages, msg)

        if #messages >= MAX_ALERTS_PER_MESSAGE then
          break
        end
      end

      local missing = #notifications - #messages

      if missing > 0 then
        table.insert(messages, "NOTE: " .. missing .. " older messages have been suppressed")
      end

      messages = table.concat(messages, "\n")

      if not slack.sendMessage(entity_type, severity, messages) then
        -- Note: upon failure we'll possibly resend already sent messages
        return {success=false, error_message="Unable to send slack messages"}
      end
    end
  end

  -- Remove all the messages from queue on success
  ntop.delCache(queue)

  return {success=true}
end

-- ##############################################

function slack.handlePost()
  local message_info, message_severity

  if(_POST["send_test_slack"] ~= nil) then
    local success = slack.sendMessage("interface", "info", "Slack notification is working")

    if success then
       message_info = i18n("prefs.slack_sent_successfully", {channel=slack.getChannelName("interface")})
       message_severity = "alert-success"
    else
       message_info = i18n("prefs.slack_send_error", {product=product})
       message_severity = "alert-danger"
    end
  end

  return message_info, message_severity
end

-- ##############################################

function slack.printPrefs(alert_endpoints, subpage_active, showElements)
  print('<thead class="thead-light"><tr><th colspan=2 class="info"><i class="fab fa-slack" aria-hidden="true"></i> '..i18n('prefs.slack_integration')..'</th></tr></thead>')

  local elementToSwitchSlack = {"row_notification_severity_preference", "slack_sender_username", "slack_webhook", "slack_test", "slack_channels"}

  prefsToggleButton(subpage_active, {
    field = "toggle_slack_notification",
    pref = alert_endpoints.getAlertNotificationModuleEnableKey("slack", true),
    default = "0",
    disabled = showElements==false,
    to_switch = elementToSwitchSlack,
  })

  local showSlackNotificationPrefs = false
  if ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey("slack")) == "1" then
     showSlackNotificationPrefs = true
  else
     showSlackNotificationPrefs = false
  end

  multipleTableButtonPrefs(subpage_active.entries["notification_severity_preference"].title, subpage_active.entries["notification_severity_preference"].description,
               alert_endpoints.getSeverityLabels(), alert_endpoints.getSeverityValues(), "error", "primary", "notification_severity_preference",
         alert_endpoints.getAlertNotificationModuleSeverityKey("slack"), nil, nil, nil, nil, showElements and showSlackNotificationPrefs)

  prefsInputFieldPrefs(subpage_active.entries["sender_username"].title, subpage_active.entries["sender_username"].description,
           "ntopng.prefs.alerts.", "slack_sender_username",
           "ntopng Webhook", nil, showElements and showSlackNotificationPrefs, false, nil, {attributes={spellcheck="false"}, required=true})

  prefsInputFieldPrefs(subpage_active.entries["slack_webhook"].title, subpage_active.entries["slack_webhook"].description,
           "ntopng.prefs.alerts.", "slack_webhook",
           "", nil, showElements and showSlackNotificationPrefs, true, true, {attributes={spellcheck="false"}, style={width="43em"}, required=true, pattern=getURLPattern()})

  -- Channel settings
  print('<tr id="slack_channels" style="' .. ternary(showSlackNotificationPrefs, "", "display:none;").. '"><td><strong>' .. i18n("prefs.slack_channel_names") .. '</strong><p><small>' .. i18n("prefs.slack_channel_names_descr") .. '</small></p></td><td><table class="table table-borderless table-sm"><tr><th>'.. i18n("prefs.alert_entity") ..'</th><th>' .. i18n("prefs.slack_channel") ..'</th></tr>')

  for entity_type_raw, entity in pairsByKeys(alert_consts.alert_entities) do
    local entity_type = alert_consts.alertEntity(entity_type_raw)
    local label = alert_consts.alertEntityLabel(entity_type)
    local channel = slack.getChannelName(entity_type_raw)

    print('<tr><td>'.. label ..'</td><td><div class="form-group" style="margin:0"><input class="form-control input-sm" name="slack_ch_'.. entity_type ..'" pattern="[^\' \']*" value="'.. channel ..'"></div></td></tr>')
  end

  print('</table></td></tr>')

  print('<tr id="slack_test" style="' .. ternary(showSlackNotificationPrefs, "", "display:none;").. '"><td><button class="btn btn-secondary disable-on-dirty" type="button" onclick="sendTestSlack();" style="width:230px; float:left;">'..i18n("prefs.send_test_slack")..'</button></td></tr>')

  print[[<script>
    function sendTestSlack() {
      var params = {};

      params.send_test_slack = "";
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

      var form = paramsToForm('<form method="post"></form>', params);
      form.appendTo('body').submit();
    }
</script>]]
end

-- ##############################################

return slack
