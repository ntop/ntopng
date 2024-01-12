--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_snmp_interface_threshold_crossed = classes.class(alert)

-- ##############################################

alert_snmp_interface_threshold_crossed.meta = {
  alert_key = other_alert_keys.alert_snmp_interface_threshold_crossed,
  i18n_title = "alerts_dashboard.snmp_device_interface_threshold_crossed",
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
function alert_snmp_interface_threshold_crossed:init(device_ip, device_name, if_index, interface_name, value, threshold, threshold_sign, metric, metric_type)

  -- Call the parent constructor
  self.super:init()

  local sign = ">"
  if threshold_sign and threshold_sign < 0 then
    sign = "<"
  end

  self.alert_type_params = {
    device = device_ip,
    device_name = device_name,
    interface = if_index,
    interface_name = interface_name,
    value = value,
    threshold = threshold,
    threshold_sign = sign,
    metric = metric,
    metric_type = metric_type
  }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_snmp_interface_threshold_crossed.format(ifid, alert, alert_type_params)
  
  local value = alert_type_params.value
  
  if alert_type_params.metric_type == "Volume" then
    value = bytesToSize(alert_type_params.value)
  end

  if alert_type_params.metric_type == "Throughput" then
    value = bitsToSize(alert_type_params.value)
  end
  
  return(i18n("alerts_dashboard.snmp_device_interface_threshold_crossed_alert_description", {
    device = alert_type_params.device,
    interface_name = alert_type_params.interface_name,
    value = value,
    threshold = alert_type_params.threshold,
    threshold_sign = alert_type_params.threshold_sign,
    metric = alert_type_params.metric,
    measure_unit = alert_type_params.metric_type
  }))

  
end

-- #######################################################

return alert_snmp_interface_threshold_crossed
