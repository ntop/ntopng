--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local format_utils = require("format_utils")

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param value A number indicating the measure which crossed the threshold
-- @param threshold A number indicating the threshold compared with `value`  using operator
-- @param ip A string with the ip address of the host crossing the threshold
-- @param host A string with the host key
-- @param operator A string indicating the operator used when evaluating the threshold, one of "gt", ">", "<"
-- @param unit The unit of measure of value and threshold
-- @return A table with the alert built
local function buildActiveMonitoringTxCross(alert_severity, alert_granularity, value, threshold, ip, host, operator, unit)
   local threshold_type = {
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_type_params = {
	 value = value,
	 threshold = threshold,
	 ip = ip,
	 host = host,
	 operator = operator,
	 unit = unit
      },
   }

   return threshold_type
end

-- #######################################################

local function thresholdCrossFormatter(ifid, alert, info)
   local msg
   local host = info.host
   local numeric_ip = info.ip
   local ip_label = host and host.label or numeric_ip

   if numeric_ip ~= host.host then
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
  builder = buildActiveMonitoringTxCross,
}
