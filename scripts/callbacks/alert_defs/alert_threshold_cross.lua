--
-- (C) 2019 - ntop.org
--

local function formatThresholdCross(ifid, alert, threshold_info)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local engine_label = alertEngineLabel(alertEngine(sec2granularity(alert["alert_granularity"])))

  return i18n("alert_messages.threshold_crossed", {
    granularity = engine_label,
    metric = threshold_info.metric,
    entity = entity,
    value = string.format("%u", math.ceil(threshold_info.value)),
    op = "&"..threshold_info.operator..";",
    threshold = threshold_info.threshold,
  })
end

-- #######################################################

return {
  alert_id = 2,
  i18n_title = "alerts_dashboard.threashold_cross",
  i18n_description = formatThresholdCross,
  icon = "fa-arrow-circle-up",
}
