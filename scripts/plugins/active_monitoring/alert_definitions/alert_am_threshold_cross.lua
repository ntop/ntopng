--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local format_utils = require("format_utils")

local function thresholdCrossFormatter(ifid, alert, info)
   local plugins_utils = require("plugins_utils")
   local active_monitoring_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

   local msg
   local host = active_monitoring_utils.key2host(alert.alert_entity_val)
   local numeric_ip = info.ip
   local ip_label = host and host.host
   local m_info = active_monitoring_utils.getMeasurementInfo(host.measurement)

   if not host then
      return ""
   end

   if((not isEmptyString(numeric_ip)) and (numeric_ip ~= ip_label) and
	 (type(numeric_ip) == "string")) then
      numeric_ip = string.format("(%s)", numeric_ip)
   else
      numeric_ip = ""
   end

   if(info.value == 0) then -- host unreachable
      msg = i18n("alert_messages.ping_host_unreachable_v3",
		 {
		  host = host.label,
		  numeric_ip = numeric_ip})
   else -- host too slow
      if(m_info and (m_info.operator == "lt")) then
	 i18n_s = "alert_messages.measurement_too_low_msg"
      else
	 i18n_s = "alert_messages.measurement_too_high_msg"
      end

      local unit = "active_monitoring_stats.msec"

      if m_info and m_info.i18n_unit then
	 unit = m_info.i18n_unit
      end

      unit = i18n(unit) or unit

      msg = i18n(i18n_s, {
	 host = host.label,
	 numeric_ip = numeric_ip,
	 am_value = format_utils.round(info.value, 2),
	 threshold = info.threshold,
	 unit = unit,
      })
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
