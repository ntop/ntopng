--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_potentially_dangerous_protocol,
  i18n_title = "alerts_dashboard.potentially_dangerous_protocol",
  i18n_description = "alert_messages.potentially_dangerous_protocol_description",
  icon = "fas fa-exclamation",
}
