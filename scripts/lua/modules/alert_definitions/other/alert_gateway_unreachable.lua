--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

local format_utils = require "format_utils"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_gateway_unreachable = classes.class(alert)

-- ##############################################

alert_gateway_unreachable.meta = {
  alert_key = other_alert_keys.alert_gateway_unreachable,
  i18n_title = "alerts_dashboard.gateway_unreachable",
  icon = "fas fa-fw fa-plug",
  entities = {
    alert_entities.system
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param ps_name A string with the name of the periodic activity
-- @param max_duration_ms The maximum duration taken by this periodic activity to run, in milliseconds
-- @return A table with the alert built
function alert_gateway_unreachable:init(name)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      name = name,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_gateway_unreachable.format(ifid, alert, alert_type_params)
  return(i18n("alert_messages.gateway_unreachable", {
    name = alert_type_params.name,
  }))
end

return alert_gateway_unreachable
