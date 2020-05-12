--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

local function createKPoNSPAlert(alert_severity)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
      }
   }

   return built
end

-- #######################################################

return {
   -- scripts/lua/modules/alert_keys.lua
   alert_key = alert_keys.ntopng.alert_known_proto_on_non_std_port,
   -- scripts/locales/en.lua
   i18n_title = "alerts_dashboard.known_proto_on_non_std_port",
   icon = "fab fa-exclamation",
   creator = createKPoNSPAlert,
}
