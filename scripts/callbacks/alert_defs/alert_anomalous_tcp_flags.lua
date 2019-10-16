--
-- (C) 2019 - ntop.org
--

local function anomalousTCPFlagsFormatter(ifid, alert, info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  return(i18n("alert_messages.anomalous_tcp_flags", {
    entity = firstToUpper(entity),
    ratio = round(info.ratio, 1),
    sent_or_rcvd = ternary(info.is_sent, i18n("graphs.metrics_suffixes.sent"), string.lower(i18n("received"))),
  }))
end

-- #######################################################

return {
  alert_id = 45,
  i18n_title = "alerts_dashboard.anomalous_tcp_flags",
  i18n_description = anomalousTCPFlagsFormatter,
  icon = "fa-exclamation",
}
