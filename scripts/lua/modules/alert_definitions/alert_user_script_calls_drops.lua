--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param subdir The subdirectory of the script (e.g., 'flow', 'host', ...)
-- @param drops The number of dropped calls
-- @return A table with the alert built
local function createUserScriptCallsDrops(alert_severity, alert_granularity, subdir, drops)
   local built = {
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_subtype = subdir,
      alert_type_params = {
	 drops = drops,
      },
   }

   return built
end

-- #######################################################

local function formatUserScriptsCallsDrops(ifid, alert, alert_info)
  if(alert.alert_subtype == "flow") then
    return(i18n("alerts_dashboard.flow_user_scripts_calls_drops_description", {
      num_drops = alert_info.drops,
      url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=callbacks&tab=flows&ifid=" .. string.format("%d", ifid),
    }))
  end

  return("")
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_user_script_calls_drops,
  i18n_title = "alerts_dashboard.user_scripts_calls_drops",
  icon = "fas fa-tint",
  i18n_description = formatUserScriptsCallsDrops,
  creator = createUserScriptCallsDrops,
}
