--
-- (C) 2019 - ntop.org
--

local function formatFlowsFlood(ifid, alert, threshold_info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  if(alert.alert_subtype == "flow_flood_attacker") then
    return i18n("alert_messages.flow_flood_attacker", {
      entity = firstToUpper(entity),
      value = string.format("%u", math.ceil(threshold_info.value)),
      threshold = threshold_info.threshold,
    })
  else
    return i18n("alert_messages.flow_flood_victim", {
      entity = firstToUpper(entity),
      value = string.format("%u", math.ceil(threshold_info.value)),
      threshold = threshold_info.threshold,
    })
  end
end

-- #######################################################

return {
  alert_id = 1,
  i18n_title = "alerts_dashboard.flows_flood",
  i18n_description = formatFlowsFlood,
  icon = "fa-life-ring",
}
