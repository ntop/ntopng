--
-- (C) 2019 - ntop.org
--

local function formatSynScan(ifid, alert, threshold_info)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  if(alert.alert_subtype == "syn_scan_attacker") then
    return i18n("alert_messages.syn_scan_attacker", {
      entity = firstToUpper(entity),
      value = string.format("%u", math.ceil(threshold_info.value)),
      threshold = threshold_info.threshold,
    })
  else
    return i18n("alert_messages.syn_scan_victim", {
      entity = firstToUpper(entity),
      value = string.format("%u", math.ceil(threshold_info.value)),
      threshold = threshold_info.threshold,
    })
  end
end

-- ##############################################

return {
  alert_id = 50,
  i18n_title = "alerts_dashboard.tcp_syn_scan",
  i18n_description = formatSynScan,
  icon = "fa-life-ring",
}
