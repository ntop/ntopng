--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param device_ip A string with the ip address of the snmp device
-- @param if_index The index of the port that changed
-- @param interface_name The string with the name of the port that changed
-- @param status The new duplex status
-- @return A table with the alert built
local function createPortDuplexstatusChange(alert_severity, device_ip, if_index, interface_name, status)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 device = device_ip,
	 interface = if_index,
	 interface_name = interface_name,
	 status = status
      },
   }

   return built
end

-- #######################################################

local function snmpPortDuplexChangeFormatter(ifid, alert, info)
  local snmp_consts = require "snmp_consts"

  return(i18n("alerts_dashboard.snmp_port_changed_duplex_status",
    {device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface),
     new_op = snmp_consts.snmp_duplexstatus(info.status)}))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_port_duplexstatus_change,
  i18n_title = "alerts_dashboard.snmp_port_duplexstatus_change",
  i18n_description = snmpPortDuplexChangeFormatter,
  icon = "fas fa-exclamation",
  creator = createPortDuplexstatusChange,
}
