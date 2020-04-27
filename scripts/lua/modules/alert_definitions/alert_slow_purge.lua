--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param idle Number of entries in state idle
-- @param idle_perc Fraction of entries in state idle, with reference to the total number of entries (idle + active)
-- @param threshold Threshold compared against idle_perc
-- @return A table with the alert built
local function createSlowPurge(alert_severity, alert_granularity, idle, idle_perc, threshold)
   local built = {
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_type_params = {
	 idle = idle,
	 idle_perc = idle_perc,
	 edge = threshold,
      },
   }

   return built
end

-- #######################################################

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
  creator = createSlowPurge,
}
