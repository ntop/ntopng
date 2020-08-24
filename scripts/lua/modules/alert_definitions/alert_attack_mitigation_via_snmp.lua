--
-- (C) 2020 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

local function formatAttackMitigationViaSNMPAlert(ifid, alert, threshold_info)
   local alert_consts = require("alert_consts")
   local snmp_consts = require "snmp_consts"
   local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
   local engine_label = alert_consts.alertEngineLabel(alert_consts.alertEngine(alert_consts.sec2granularity(alert["alert_granularity"])))

   local i18n_k = "alert_messages.attack_mitigation_via_snmp_success"
   if not threshold_info.success then
      i18n_k = "alert_messages.attack_mitigation_via_snmp_failure"
   end

   return i18n(i18n_k, {
		  granularity = engine_label:lower(),
		  metric = threshold_info.metric,
		  entity = entity,
		  value = string.format("%u", math.ceil(threshold_info.value)),
		  op = "&".. (threshold_info.operator or "gt") ..";",
		  threshold = threshold_info.threshold,
		  device = threshold_info.access_port.snmp_device_ip,
		  url = snmpDeviceUrl(threshold_info.access_port.snmp_device_ip),
		  port = threshold_info.access_port.id,
		  port_url = snmpIfaceUrl(threshold_info.access_port.snmp_device_ip, threshold_info.access_port.id),
		  admin_down = snmp_consts.snmp_ifstatus("2" --[[ down --]])
   })
end

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param alert_subtype A string indicating the subtype for this threshold cross (e.g,. 'score', 'active', 'packets', ...)
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param metric Same as `alert_subtype`
-- @param value A number indicating the measure which crossed the threshold
-- @param operator A string indicating the operator used when evaluating the threshold, one of "gt", ">", "<"
-- @param threshold A number indicating the threshold compared with `value`  using operator
-- @param access_port A table containing access port details with keys: name, trunk, id, and snmp_device_ip
-- @param success Whether the admin status of the port has been successfully toggled to down
-- @return A table with the alert built
function createAttackMitigationViaSNMPAlert(alert_severity, alert_subtype, alert_granularity, metric, value, operator, threshold, access_port, success)
   local threshold_type = {
      alert_subtype = alert_subtype,
      alert_granularity = alert_granularity,
      alert_severity = alert_severity,
      alert_type_params = {
	 metric = metric,
	 value = value,
	 operator = operator,
	 threshold = threshold,
	 access_port = access_port,
	 success = success
      }
   }

   return threshold_type
end

-- #######################################################

return {
   alert_key = alert_keys.ntopng.alert_attack_mitigation_via_snmp,
   i18n_title = "alerts_dashboard.attack_mitigation_snmp_title",
   i18n_description = formatAttackMitigationViaSNMPAlert,
   icon = "fa fa-stop-circle",
   creator = createAttackMitigationViaSNMPAlert,
}
