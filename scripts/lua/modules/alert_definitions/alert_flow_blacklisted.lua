--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_flow_blacklisted,
  i18n_title = "alerts_dashboard.blacklisted_flow",
  icon = "fas fa-exclamation",
}
