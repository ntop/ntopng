--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param info A lua table containing flow information obtained with `flow.getInfo()`
-- @return A table with the alert built
local function createKPoNSPAlert(alert_severity, info)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = info
   }

   return built
end

-- #######################################################

return {
   -- scripts/lua/modules/alert_keys.lua
   alert_key = alert_keys.ntopng.alert_known_proto_on_non_std_port,
   -- scripts/locales/en.lua
   i18n_title = "alerts_dashboard.known_proto_on_non_std_port",
   icon = "fas fa-exclamation",
   creator = createKPoNSPAlert,
}
