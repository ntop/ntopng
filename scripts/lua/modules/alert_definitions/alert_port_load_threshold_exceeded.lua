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
-- @param in_load The ingress load in percentage
-- @param out_load The egress load in percentage
-- @param load_threshold The threshold configured for the load
-- @return A table with the alert built
local function createPortLoadThresholdExceeded(alert_severity, device_ip, if_index, interface_name, in_load, out_load, load_threshold)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 device = device_ip,
	 interface = if_index,
	 interface_name = interface_name,
	 in_load = in_load,
	 out_load = out_load,
	 load_threshold = load_threshold,
      },
   }

   return built
end

-- #######################################################

local function snmpPortLoadThresholdFormatter(ifid, alert, info)
  local fmt = {
     device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface),
     in_load = info.in_load,
     out_load = info.out_load,
     threshold = info.load_threshold,
  }

  return(i18n("alerts_dashboard.snmp_port_load_threshold_exceeded_message", fmt))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_port_load_threshold_exceeded,
  i18n_title = "alerts_dashboard.snmp_port_load_threshold_exceeded",
  i18n_description = snmpPortLoadThresholdFormatter,
  icon = "fas fa-exclamation",
  creator = createPortLoadThresholdExceeded,
}
