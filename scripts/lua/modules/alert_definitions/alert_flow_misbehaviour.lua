--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param l2r_threshold Local-to-Remote threshold, in bytes, for a flow to be considered an elephant
-- @param r2l_threshold Remote-to-Local threshold, in bytes, for a flow to be considered an elephant
-- @return A table with the alert built
local function buildFlowMisbehaviour(alert_severity, l2r_threshold, r2l_threshold)
   local built = {
      alert_severity = alert_severity,
      ["elephant.l2r_threshold"] = l2r_threshold,
      ["elephant.r2l_threshold"] = r2l_threshold,
   }

   return built
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_flow_misbehaviour,
  i18n_title = "alerts_dashboard.flow_misbehaviour",
  icon = "fas fa-exclamation",
  builder = buildFlowMisbehaviour,
}
