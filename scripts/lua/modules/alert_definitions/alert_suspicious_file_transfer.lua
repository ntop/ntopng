--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param http_info A lua table containing flow HTTP information obtained with `flow.getHTTPInfo()`
-- @return A table with the alert built
local function createBATAlert(alert_severity, http_info)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = http_info
   }

   return built
end

-- #######################################################

return {
   -- scripts/lua/modules/alert_keys.lua
   alert_key = alert_keys.ntopng.alert_suspicious_file_transfer,
   -- scripts/locales/en.lua
   i18n_title = "alerts_dashboard.suspicious_file_transfer",
   icon = "fas fa-file-download",
   creator = createBATAlert,
}
