--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param device_ip A string with the ip address of the snmp device
-- @param if_index The index of the port that changed
-- @param interface_name The string with the name of the port that changed
-- @return A table with the alert built
local function createPortErrors(alert_severity, device_ip, if_index, interface_name)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 device = device_ip,
	 interface = if_index,
	 interface_name = interface_name,
      },
   }

   return built
end

-- #######################################################

local function snmpInterfaceErrorsFormatter(ifid, alert, info)
  return(i18n("alerts_dashboard.snmp_port_errors_increased",
    {device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface)}))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_port_errors,
  i18n_title = "alerts_dashboard.snmp_port_errors",
  i18n_description = snmpInterfaceErrorsFormatter,
  icon = "fas fa-exclamation",
  creator = createPortErrors,
}
