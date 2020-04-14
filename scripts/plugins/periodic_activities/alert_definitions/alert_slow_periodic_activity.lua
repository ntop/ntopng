--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local format_utils = require "format_utils"

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
}
