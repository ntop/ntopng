--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function processNotificationFormatter(ifid, alert, info)
  if info.event_type == "start" then
    return string.format("%s %s", i18n("alert_messages.ntopng_start"), info.msg_details)
  elseif info.event_type == "stop" then
    return string.format("%s %s", i18n("alert_messages.ntopng_stop"), info.msg_details)
  elseif info.event_type == "update" then
    return string.format("%s %s", i18n("alert_messages.ntopng_update"), info.msg_details)
  elseif info.event_type == "anomalous_termination" then
    return string.format("%s %s", i18n("alert_messages.ntopng_anomalous_termination", {url="https://www.ntop.org/support/need-help-2/need-help/"}), info.msg_details)
  end

  return "Unknown Process Event: " .. (info.event_type or "")
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_process_notification,
  i18n_title = "alerts_dashboard.process",
  i18n_description = processNotificationFormatter,
  icon = "fas fa-truck",
}
