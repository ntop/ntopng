--
-- (C) 2019 - ntop.org
--

local function misbehavingFlowsRatioFormatter(ifid, alert, info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  return(i18n("alert_messages.misbehaving_flows_ratio", {
    entity = firstToUpper(entity),
    ratio = round(info.ratio, 1),
    sent_or_rcvd = ternary(info.is_sent, i18n("graphs.metrics_suffixes.sent"), string.lower(i18n("received"))),
  }))
end

-- #######################################################

return {
  alert_id = 46,
  i18n_title = "alerts_dashboard.misbehaving_flows_ratio",
  i18n_description = misbehavingFlowsRatioFormatter,
  icon = "fa-exclamation",
}
