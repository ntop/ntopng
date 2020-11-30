--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param last_error A string with the lastest influxdb error
-- @return A table with the alert built
local function createInfluxdbError(alert_severity, alert_granularity, last_error)
   local threshold_type = {
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_type_params = {
	 error_msg = last_error
      },
   }

   return threshold_type
end

-- #######################################################

local function formatInfluxdbErrorMessage(ifid, alert, status)
  return(status.error_msg)
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_influxdb_error,
  i18n_title = "alerts_dashboard.influxdb_error",
  i18n_description = formatInfluxdbErrorMessage,
  icon = "fas fa-database",
  creator = createInfluxdbError,
}
