--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

function requestReplyRatioFormatter(ifid, alert, info)
  local alert_consts = require("alert_consts")

  local entity = firstToUpper(alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"]))
  local engine_label = alert_consts.alertEngineLabel(alert_consts.alertEngine(alert_consts.sec2granularity(alert["alert_granularity"])))
  local ratio = round(math.min((info.replies * 100) / (info.requests + 1), 100), 1)

  -- {i18_string, what}
  local subtype_to_info = {
    dns_sent = {"alerts_dashboard.too_low_replies_received", "DNS"},
    dns_rcvd = {"alerts_dashboard.too_low_replies_sent", "DNS"},
    http_sent = {"alerts_dashboard.too_low_replies_received", "HTTP"},
    http_rcvd = {"alerts_dashboard.too_low_replies_sent", "HTTP"},
    icmp_echo_sent = {"alerts_dashboard.too_low_replies_received", "ICMP ECHO"},
    icmp_echo_rcvd = {"alerts_dashboard.too_low_replies_received", "ICMP ECHO"},
  }

  local subtype_info = subtype_to_info[alert.alert_subtype]

  return(i18n(subtype_info[1], {
    entity = entity,
    granularity = engine_label,
    ratio = ratio,
    requests = i18n(
      ternary(info.requests == 1, "alerts_dashboard.one_request", "alerts_dashboard.many_requests"),
      {count = formatValue(info.requests), what = subtype_info[2]}),
    replies =  i18n(
      ternary(info.replies == 1, "alerts_dashboard.one_reply", "alerts_dashboard.many_replies"),
      {count = formatValue(info.replies), what = subtype_info[2]}),
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_request_reply_ratio,
  i18n_title = "entity_thresholds.request_reply_ratio_title",
  i18n_description = requestReplyRatioFormatter,
  icon = "fas fa-exclamation",
}
