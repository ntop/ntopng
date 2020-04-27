--
-- (C) 2019-20 - ntop.org
--

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param info A flow info table fetched with `flow.getBlacklistedInfo()`
-- @return A table with the alert built
local function createBlacklisted(alert_severity, info)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = info,
   }

   return built
end

-- #######################################################

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_flow_blacklisted,
  i18n_title = "alerts_dashboard.blacklisted_flow",
  icon = "fas fa-exclamation",
  creator = createBlacklisted,
}
