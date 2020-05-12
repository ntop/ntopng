--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

local function createBATAlert(alert_severity)
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
   alert_key = alert_keys.ntopng.alert_binary_application_transfer,
   -- scripts/locales/en.lua
   i18n_title = "alerts_dashboard.binary_application_transfer",
   icon = "fab fa-exclamation",
   creator = createBATAlert,
}
