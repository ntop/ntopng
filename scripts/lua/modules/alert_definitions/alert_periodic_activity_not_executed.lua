--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local format_utils = require "format_utils"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param ps_name A string with the name of the periodic activity
-- @param last_queued_time The time when the periodic activity was executed for the last time, as a unix epoch
-- @return A table with the alert built
local function createPeriodicActivityNotExecuted(alert_severity, alert_granularity, ps_name, last_queued_time)
   local threshold_type = {
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_subtype = ps_name,
      alert_type_params = {
	 ps_name = ps_name,
	 last_queued_time = last_queued_time,
      },
   }

   return threshold_type
end

-- #######################################################

local function formatPeriodicActivityNotExecuted(ifid, alert, info)
   return(i18n("alert_messages.periodic_activity_not_executed",
	       {
		  script = info.ps_name,
		  pending_since = format_utils.formatPastEpochShort(info.last_queued_time),
   }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_periodic_activity_not_executed,
  i18n_title = "alerts_dashboard.periodic_activity_not_executed",
  i18n_description = formatPeriodicActivityNotExecuted,
  icon = "fas fa-undo",
  creator = createPeriodicActivityNotExecuted,
}
