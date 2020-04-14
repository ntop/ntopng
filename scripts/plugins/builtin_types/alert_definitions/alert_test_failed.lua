--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_test_failed,
  i18n_title = "alert_messages.test_failed",
  icon = "fas fa-exclamation",
}
