--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_udp_unidirectional,
  i18n_title = "alerts_dashboard.udp_unidirectional",
  icon = "fas fa-exclamation",
}
