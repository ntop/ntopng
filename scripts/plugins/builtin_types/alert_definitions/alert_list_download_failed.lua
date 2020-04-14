--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_list_download_failed,
  i18n_title = "alerts_dashboard.list_download_failed",
  i18n_description = "category_lists.error_occurred",
  icon = "fas fa-sticky-note",
}
