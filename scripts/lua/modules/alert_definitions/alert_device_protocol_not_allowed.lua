--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_device_protocol_not_allowed,
  i18n_title = "alerts_dashboard.suspicious_device_protocol",
  icon = "fas fa-exclamation",
}
