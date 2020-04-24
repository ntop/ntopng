--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param influxdb The url used to export the points
-- @return A table with the alert built
local function buildInfluxdbDroppedPoints(alert_severity, alert_granularity, influxdb)
   local built = {
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_type_params = {
	 influxdb = influxdb,
      },
   }

   return built
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_influxdb_export_failure,
  i18n_title = "alerts_dashboard.influxdb_export_failure",
  i18n_description = "alert_messages.influxdb_dropped_points",
  icon = "fas fa-database",
  builder = buildInfluxdbDroppedPoints,
}
