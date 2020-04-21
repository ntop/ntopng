--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function formatInfluxdbErrorMessage(ifid, alert, status)
  return(status.error_msg)
end

return {
  alert_key = alert_keys.ntopng.alert_influxdb_error,
  i18n_title = "alerts_dashboard.influxdb_error",
  i18n_description = formatInfluxdbErrorMessage,
  icon = "fas fa-database",
}
