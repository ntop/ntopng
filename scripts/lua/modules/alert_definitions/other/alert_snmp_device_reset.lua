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

local alert_snmp_device_reset = classes.class(alert)

-- ##############################################

alert_snmp_device_reset.meta = {
   alert_key = other_alert_keys.alert_snmp_device_reset,
   i18n_title = "alerts_dashboard.alert_snmp_device_reset_title",
   icon = "fas fa-fw fa-power-off",
  entities = {
    alert_entities.snmp_device
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param device_ip A string with the ip address of the snmp device
-- @param device_name The device name
-- @return A table with the alert built
function alert_snmp_device_reset:init(device_ip, device_name)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      device = device_ip,
      device_name = device_name
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_snmp_device_reset.format(ifid, alert, alert_type_params)
   return(i18n("alerts_dashboard.alert_snmp_device_reset_description",
	       {device = alert_type_params.device,
		url = snmpDeviceUrl(alert_type_params.device)}))
end

-- #######################################################

return alert_snmp_device_reset
