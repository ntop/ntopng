--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_blacklisted_country,
  i18n_title = "alerts_dashboard.blacklisted_country",
  icon = "fas fa-exclamation",
}
