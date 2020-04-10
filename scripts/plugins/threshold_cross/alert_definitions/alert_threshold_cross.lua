--
-- (C) 2019-20 - ntop.org
--

local function formatThresholdCross(ifid, alert, threshold_info)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local engine_label = alert_consts.alertEngineLabel(alert_consts.alertEngine(alert_consts.sec2granularity(alert["alert_granularity"])))

  return i18n("alert_messages.threshold_crossed", {
    granularity = engine_label,
    metric = threshold_info.metric,
    entity = entity,
    value = string.format("%u", math.ceil(threshold_info.value)),
    op = "&".. (threshold_info.operator or "gt") ..";",
    threshold = threshold_info.threshold,
  })
end

-- #######################################################

return {
  i18n_title = "alerts_dashboard.threashold_cross",
  i18n_description = formatThresholdCross,
  icon = "fas fa-arrow-circle-up",
}
