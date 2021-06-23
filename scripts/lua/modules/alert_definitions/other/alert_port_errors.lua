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

local alert_port_errors = classes.class(alert)

-- ##############################################

alert_port_errors.meta = {
   alert_key = other_alert_keys.alert_port_errors,
   i18n_title = "alerts_dashboard.snmp_port_errors",
   icon = "fas fa-fw fa-exclamation",
   entities = {
      alert_entities.snmp_device
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param device_ip A string with the ip address of the snmp device
-- @param device_name The name of the snmp device
-- @param if_index The index of the port that changed
-- @param interface_name The string with the name of the port that changed
-- @return A table with the alert built
function alert_port_errors:init(device_ip, device_name, if_index, interface_name)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      device = device_ip,
      device_name = device_name,
      interface = if_index,
      interface_name = interface_name,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_port_errors.format(ifid, alert, alert_type_params)
   return(i18n("alerts_dashboard.snmp_port_errors_increased",
	       {
		  device = alert_type_params.device,
		  port = alert_type_params.interface_name or alert_type_params.interface,
		  url = snmpDeviceUrl(alert_type_params.device),
		  port_url = snmpIfaceUrl(alert_type_params.device, alert_type_params.interface)
   }))
end

-- #######################################################

return alert_port_errors
