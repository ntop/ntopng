--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param info A generic table decoded from a JSON originated at the external alert source
-- @return A table with the alert built
local function buildExternal(alert_severity, info)
   local built = {
      alert_severity = alert_severity,
      info = info
   }

   return built
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_external,
  i18n_title = "alerts_dashboard.external_alert",
  icon = "fas fa-eye",
  builder = buildExternal,
}
