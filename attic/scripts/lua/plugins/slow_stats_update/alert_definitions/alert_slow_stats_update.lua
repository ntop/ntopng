--
-- (C) 2019-21 - ntop.org
--

local function formatSlowStatsUpdate(ifid, alert, threshold_info)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  return(i18n("alert_messages.slow_stats_update", {
    iface = entity,
    url = ntop.getHttpPrefix() .."/lua/admin/prefs.lua?tab=in_memory",
    pref_name = i18n("prefs.housekeeping_frequency_title"),
  }))
end

-- #######################################################

return {
  i18n_title = "alerts_dashboard.slow_stats_update",
  icon = "fas fa-exclamation",
  i18n_description = formatSlowStatsUpdate,
}
