--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

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
}
