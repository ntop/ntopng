--
-- (C) 2019 - ntop.org
--

local function formatDNSAnomaly(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   alert_consts = require("alert_consts")
   -- tprint({ifid =ifid, engine = engine, entity_type = entity_type, entity_value = entity_value, entity_info = entity_info, alert_key = alert_key, alert_info = alert_info})

   if entity_info.anomalies ~= nil then
      for _, v in pairs({"dns.rcvd.num_replies_ok", "dns.rcvd.num_queries", "dns.rcvd.num_replies_error",
			 "dns.sent.num_replies_ok", "dns.sent.num_queries", "dns.sent.num_replies_error"}) do
	 if alert_key == v and entity_info.anomalies[v] then
	    local anomaly_info = entity_info.anomalies[v]

	    local res =  string.format("%s has a DNS anomaly [%s][current=%u][anomaly_index=%u]",
				       firstToUpper(alert_consts.formatAlertEntity(ifid, entity_type, entity_value, entity_info)),
				       v,
				       anomaly_info.value,
				       anomaly_info.anomaly_index)
	    return res
	 end
      end
   end

   return ""
end

-- #######################################################

return {
  alert_id = 32,
  i18n_title = "alerts_dashboard.dns_anomaly",
  icon = "fa-life-ring",
  i18n_description = formatDNSAnomaly,
}
