--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_unresponsive_device,
  i18n_title = "alerts_dashboard.unresponsive_device",
  icon = "fas fa-exclamation",
}
