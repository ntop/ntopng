--
-- (C) 2019 - ntop.org
--

local function formatSlowPurge(ifid, alert, threshold_info)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local max_idle_perc = threshold_info.threshold or 0

  return(i18n("alert_messages.slow_purge", {
    iface = entity, max_idle = max_idle_perc
  }))
end

-- #######################################################

return {
  alert_id = 51,
  i18n_title = "alerts_dashboard.slow_purge",
  icon = "fa-exclamation",
  i18n_description = formatSlowPurge,
}
