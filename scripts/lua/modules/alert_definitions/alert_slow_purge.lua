--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function formatSlowPurge(ifid, alert, threshold_info)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local max_idle_perc = threshold_info.threshold or 0

  return(i18n("alert_messages.slow_purge", {
    iface = entity, max_idle = max_idle_perc,
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. ifid .. "&page=internals",
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_slow_purge,
  i18n_title = "alerts_dashboard.slow_purge",
  icon = "fas fa-exclamation",
  i18n_description = formatSlowPurge,
}
