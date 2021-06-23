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

local alert_port_mac_changed = classes.class(alert)

-- ##############################################

alert_port_mac_changed.meta = {
   alert_key = other_alert_keys.alert_port_mac_changed,
   i18n_title = "alerts_dashboard.alert_snmp_interface_mac_changed_title",
   icon = "fas fa-fw fa-exclamation",
   entities = {},
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param device_ip A string with the ip address of the snmp device
-- @param device_name The device name
-- @param if_index The index of the port that changed
-- @param interface_name The string with the name of the port that changed
-- @param mac The string with the mac address that changed port
-- @param prev_seen_device A string with the ip address of the previous snmp device
-- @param prev_seen_port The index of the previous port
-- @return A table with the alert built
function alert_port_mac_changed:init(device_ip, device_name, if_index, interface_name, mac, prev_seen_device, prev_seen_port)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      device = device_ip,
      device_name = device_name,
      interface = if_index,
      interface_name = interface_name,
      mac = mac,
      prev_seen_device = prev_seen_device,
      prev_seen_port = prev_seen_port,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_port_mac_changed.format(ifid, alert, alert_type_params)
   return(i18n("alerts_dashboard.alert_snmp_interface_mac_changed_description",
	       {mac_url = getMacUrl(alert_type_params.mac),
		mac = alert_type_params.mac,
		device = alert_type_params.device,
		port = alert_type_params.interface_name or alert_type_params.interface,
		url = snmpDeviceUrl(alert_type_params.device),
		port_url = snmpIfaceUrl(alert_type_params.device, alert_type_params.interface),
		prev_device_url = snmpDeviceUrl(alert_type_params.prev_seen_device),
		prev_device = alert_type_params.prev_seen_device,
		prev_port_url = snmpIfaceUrl(alert_type_params.prev_seen_device, alert_type_params.prev_seen_port),
		prev_port = alert_type_params.prev_seen_port}))
end

-- #######################################################

return alert_port_mac_changed
