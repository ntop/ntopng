--
-- (C) 2019-20 - ntop.org
--

local format_utils = require("format_utils")
local active_monitoring_utils = require("active_monitoring_utils")

local function pingIssuesFormatter(ifid, alert, info)
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

      msg = i18n(i18n_s,
		 {
		  host = host.label,
		  numeric_ip = numeric_ip,
		  rtt_value = format_utils.round(info.value, 2),
		  maximum_rtt = info.threshold})
   end

   return msg
end

-- #######################################################

return {
  i18n_title = "graphs.active_monitoring",
  i18n_description = pingIssuesFormatter,
  icon = "fas fa-exclamation",
}
