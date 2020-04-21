--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_flow_blocked,
  i18n_title = "alerts_dashboard.blocked_flow",
  icon = "fas fa-ban",
}
