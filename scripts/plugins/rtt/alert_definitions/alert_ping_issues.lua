--
-- (C) 2019-20 - ntop.org
--

local format_utils = require("format_utils")

local function pingIssuesFormatter(ifid, alert, info)
   local msg
   -- example of an ip label:
   -- google-public-dns-b.google.com@ipv4@icmp/216.239.38.120
   local ip_label = (alert.alert_entity_val:split("@") or {alert.alert_entity_val})[1]
   local numeric_ip = alert.ip

   if numeric_ip and numeric_ip ~= ip_label then
      numeric_ip = string.format("[%s]", numeric_ip)
   else
      numeric_ip = ""
   end

   if(info.value == 0) then -- host unreachable
      msg = i18n("alert_messages.ping_host_unreachable",
		 {ip_label = ip_label,
		  numeric_ip = numeric_ip})
   else -- host too slow
      msg = i18n("alert_messages.ping_rtt_too_slow",
		 {ip_label = unescapeHttpHost(ip_label),
		  numeric_ip = numeric_ip,
		  rtt_value = format_utils.round(info.value, 2),
		  maximum_rtt = info.threshold})
   end

   return msg
end

-- #######################################################

return {
  i18n_title = "alerts_dashboard.ping_issues",
  i18n_description = pingIssuesFormatter,
  icon = "fas fa-exclamation",
}
