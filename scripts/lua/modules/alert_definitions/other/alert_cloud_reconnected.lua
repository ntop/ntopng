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

local alert_cloud_reconnected = classes.class(alert)

-- ##############################################

alert_cloud_reconnected.meta = {
  alert_key = other_alert_keys.alert_cloud_reconnected,
  i18n_title = "cloud.reconnection",
  icon = "fas fa-fw fa-cloud",
  entities = {
    alert_entities.system
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_cloud_reconnected:init()
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {}
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_cloud_reconnected.format(ifid, alert, alert_type_params)
  return(i18n("cloud.reconnected"))
end

-- #######################################################

return alert_cloud_reconnected
