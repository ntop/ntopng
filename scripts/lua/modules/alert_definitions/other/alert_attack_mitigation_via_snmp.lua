--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_attack_mitigation_via_snmp = classes.class(alert)

-- ##############################################

alert_attack_mitigation_via_snmp.meta = {
   alert_key = other_alert_keys.alert_attack_mitigation_via_snmp,
   i18n_title = "alerts_dashboard.attack_mitigation_snmp_title",
   icon = "fa fa-stop-circle",
   entities = {
      alert_entities.snmp_device
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param metric Same as `alert_subtype`
-- @param value A number indicating the measure which crossed the threshold
-- @param operator A string indicating the operator used when evaluating the threshold, one of "gt", ">", "<"
-- @param threshold A number indicating the threshold compared with `value`  using operator
-- @param access_port A table containing access port details with keys: name, trunk, id, and snmp_device_ip
-- @param success Whether the admin status of the port has been successfully toggled to down
-- @return A table with the alert built
function alert_attack_mitigation_via_snmp:init(metric, value, operator, threshold, access_port, success)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      metric = metric,
      value = value,
      operator = operator,
      threshold = threshold,
      access_port = access_port,
      success = success
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_attack_mitigation_via_snmp.format(ifid, alert, alert_type_params)
   local alert_consts = require("alert_consts")
   local snmp_consts = require "snmp_consts"

   local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["entity_id"]), alert["entity_val"])
   local engine_label = alert_consts.alertEngineLabel(alert_consts.alertEngine(alert_consts.sec2granularity(alert["alert_granularity"])))

   local i18n_k = "alert_messages.attack_mitigation_via_snmp_success"
   if not alert_type_params.success then
      i18n_k = "alert_messages.attack_mitigation_via_snmp_failure"
   end

   return i18n(i18n_k, {
		  granularity = engine_label:lower(),
		  metric = alert_type_params.metric,
		  entity = entity,
		  value = string.format("%u", math.ceil(alert_type_params.value)),
		  op = "&".. (alert_type_params.operator or "gt") ..";",
		  threshold = alert_type_params.threshold,
		  device = alert_type_params.access_port.snmp_device_ip,
		  url = snmpDeviceUrl(alert_type_params.access_port.snmp_device_ip),
		  port = alert_type_params.access_port.id,
		  port_url = snmpIfaceUrl(alert_type_params.access_port.snmp_device_ip, alert_type_params.access_port.id),
		  admin_down = snmp_consts.snmp_ifstatus("2" --[[ down --]])
   })
end

-- #######################################################

return alert_attack_mitigation_via_snmp
