--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local format_utils = require("format_utils")

local function thresholdCrossFormatter(ifid, alert, info)
   local msg
   local host = info.host
   local numeric_ip = info.ip
   local ip_label = host and host.label or numeric_ip

   if numeric_ip ~= ip_label then
      numeric_ip = string.format("(%s)", numeric_ip)
   else
      numeric_ip = ""
   end

   if(info.value == 0) then -- host unreachable
      msg = i18n("alert_messages.ping_host_unreachable_v3",
		 {host = ip_label,
		  numeric_ip = numeric_ip})
   else -- host too slow
      if info.operator == "lt" then
	 i18n_s = "alert_messages.measurement_too_low_msg"
      else
	 i18n_s = "alert_messages.measurement_too_high_msg"
      end

      local unit = "active_monitoring_stats.msec"

      if info.unit then
	 unit = info.unit
      end

      unit = i18n(unit) or unit

      local msg_table = {
	 host = ip_label,
	 numeric_ip = numeric_ip,
	 am_value = format_utils.round(info.value, 2),
	 threshold = info.threshold,
	 unit = unit,
      }

      msg = i18n(i18n_s, msg_table)
   end

   return msg
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_am_threshold_cross,
  i18n_title = "graphs.active_monitoring",
  i18n_description = thresholdCrossFormatter,
  icon = "fas fa-exclamation",
}
