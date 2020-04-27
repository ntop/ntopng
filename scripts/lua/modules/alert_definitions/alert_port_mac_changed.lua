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
-- @param mac The string with the mac address that changed port
-- @param prev_seen_device A string with the ip address of the previous snmp device
-- @param prev_seen_port The index of the previous port
-- @return A table with the alert built
local function createPortMacChange(alert_severity, device_ip, if_index, interface_name, mac, prev_seen_device, prev_seen_port)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 device = device_ip,
	 interface = if_index,
	 interface_name = interface_name,
	 mac = mac,
	 prev_seen_device = prev_seen_device,
	 prev_seen_port = prev_seen_port,
      },
   }

   return built
end

-- #######################################################

local function portMacChangedFormatter(ifid, alert, info)
   if ntop.isPro() then require "snmp_utils" end

   return(i18n("alerts_dashboard.alert_snmp_interface_mac_changed_description",
	       {mac_url = getMacUrl(info.mac),
		mac = info.mac,
		device = info.device,
		port = info.interface_name or info.interface,
		url = snmpDeviceUrl(info.device),
		port_url = snmpIfaceUrl(info.device, info.interface),
		prev_device_url = snmpDeviceUrl(info.prev_seen_device),
		prev_device = info.prev_seen_device,
		prev_port_url = snmpIfaceUrl(info.prev_seen_device, info.prev_seen_port),
		prev_port = info.prev_seen_port}))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_port_mac_changed,
   i18n_title = "alerts_dashboard.alert_snmp_interface_mac_changed_title",
   i18n_description = portMacChangedFormatter,
   icon = "fas fa-exclamation",
   creator = createPortMacChange,
}
