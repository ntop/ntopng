--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_connection_issues,
  i18n_title = "alerts_dashboard.connection_issues",
  icon = "fas fa-exclamation",
}
