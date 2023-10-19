--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_snmp_device_traffic_change = classes.class(alert)

-- ##############################################

alert_snmp_device_traffic_change.meta = {
  alert_key = other_alert_keys.alert_snmp_device_traffic_change,
  i18n_title = "alerts_dashboard.alert_snmp_traffic_change_detected",
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
function alert_snmp_device_traffic_change:init(device_ip, device_name, if_index, interface_name, curr_traffic, prev_traffic)
  -- Call the parent constructor
  self.super:init()

  self.alert_type_params = {
    device = device_ip,
    device_name = device_name,
    interface = if_index,
    interface_name = interface_name,
    curr_traffic = curr_traffic,
    prev_traffic = prev_traffic,
  }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_snmp_device_traffic_change.format(ifid, alert, alert_type_params)
  local msg_params = {
    device = alert_type_params.device,
    device_name = alert_type_params.device_name,
    port = alert_type_params.interface_name or alert_type_params.interface,
    port_index = alert_type_params.interface,
    url = snmpDeviceUrl(alert_type_params.device),
    port_url = snmpIfaceUrl(alert_type_params.device, alert_type_params.interface),
    http_prefix = ntop.getHttpPrefix()
  }
  
  if alert_type_params.curr_traffic == 0 then
    return i18n("alerts_dashboard.alert_snmp_traffic_change_detected_message_down", msg_params)
  else
    return i18n("alerts_dashboard.alert_snmp_traffic_change_detected_message_up", msg_params)
  end
end

-- #######################################################

return alert_snmp_device_traffic_change
