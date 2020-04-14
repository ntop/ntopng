--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function misbehavingFlowsRatioFormatter(ifid, alert, info)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  return(i18n("alert_messages.misbehaving_flows_ratio", {
    entity = firstToUpper(entity),
    ratio = round(info.ratio, 1),
    sent_or_rcvd = ternary(info.is_sent, i18n("graphs.metrics_suffixes.sent"), string.lower(i18n("received"))),
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_misbehaving_flows_ratio,
  i18n_title = "alerts_dashboard.misbehaving_flows_ratio",
  i18n_description = misbehavingFlowsRatioFormatter,
  icon = "fas fa-exclamation",
}
