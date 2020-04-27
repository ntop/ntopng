--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local format_utils = require "format_utils"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param ps_name A string with the name of the periodic activity
-- @param max_duration_ms The maximum duration taken by this periodic activity to run, in milliseconds
-- @return A table with the alert built
local function createSlowPeriodicActivity(alert_severity, alert_granularity, ps_name, max_duration_ms)
   local threshold_type = {
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_subtype = ps_name,
      alert_type_params = {
	 ps_name = ps_name,
	 max_duration_ms = max_duration_ms,
      },
   }

   return threshold_type
end

-- #######################################################

local function slowPeriodicActivityFormatter(ifid, alert, info)
  local max_duration

  max_duration = format_utils.secondsToTime(info.max_duration_ms / 1000)

  return(i18n("alert_messages.slow_periodic_activity", {
    script = info.ps_name,
    max_duration = max_duration,
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_slow_periodic_activity,
  i18n_title = "alerts_dashboard.slow_periodic_activity",
  i18n_description = slowPeriodicActivityFormatter,
  icon = "fas fa-undo",
  creator = createSlowPeriodicActivity,
}
