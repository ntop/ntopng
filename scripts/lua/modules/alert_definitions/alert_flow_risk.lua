--
-- (C) 2019-20 - ntop.org
--

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param risk_id Integer nDPI flow risk identifier
-- @return A table with the alert built
local function createFlowRisk(alert_severity, risk_id)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 risk_id = risk_id
      },
   }

   return built
end

-- #######################################################

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_flow_risk,
  i18n_title = "alerts_dashboard.flow_risk",
  icon = "fas fa-exclamation",
  creator = createFlowRisk,
}
