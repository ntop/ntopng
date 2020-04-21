--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

return {
  alert_key = alert_keys.ntopng.alert_influxdb_dropped_points,
  i18n_title = "alerts_dashboard.influxdb_dropped_points",
  icon = "fas fa-database",
}
