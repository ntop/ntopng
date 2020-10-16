--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @return A table with the alert built
local function createConnectionIssues(alert_severity)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {},
   }

   return built
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_connection_issues,
  i18n_title = "alerts_dashboard.connection_issues",
  icon = "fas fa-exclamation",
  creator = createConnectionIssues,
}
