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

local alert_network_discovery_executed = classes.class(alert)

-- ##############################################

alert_network_discovery_executed.meta = {  
   alert_key = other_alert_keys.alert_network_discovery_executed,
   i18n_title = "checks.network_discovery_title",
   icon = "fas fa-fw fa-arrow-circle-up",
   entities = {
      alert_entities.interface
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function alert_network_discovery_executed:init()
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
function alert_network_discovery_executed.format(ifid, alert, alert_type_params)
  return(i18n("checks.network_discovery_alert_description"))
end

-- #######################################################

return alert_network_discovery_executed
