--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
local alert_creators = require "alert_creators"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_device_connection = classes.class(alert)

-- ##############################################

alert_device_connection.meta = {
  alert_key = other_alert_keys.alert_device_connection,
  i18n_title = "alerts_dashboard.device_connection",
  icon = "fas fa-fw fa-sign-in",
  entities = {
    alert_entities.mac
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param device The a string with the name or ip address of the device that connected the network
-- @return A table with the alert built
function alert_device_connection:init(device)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    device = device,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_device_connection.format(ifid, alert, alert_type_params)
  return(i18n("alert_messages.device_has_connected", {
    device = info.device,
    url = getMacUrl(alert.entity_val),
  }))
end

-- #######################################################

return alert_device_connection
