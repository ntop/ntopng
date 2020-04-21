--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_suspicious_activity,
  i18n_title = "alerts_dashboard.suspicious_activity",
  icon = "fas fa-exclamation",
}
