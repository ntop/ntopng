--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local flow_risk_simple_alert_definition = classes.class(alert)

-- ##############################################

flow_risk_simple_alert_definition.meta = {
   -- alert_key = <added at runtime>
   -- i18n_title = <added at runtime>
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function flow_risk_simple_alert_definition:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function flow_risk_simple_alert_definition.format(ifid, alert, alert_type_params)
   return flow_risk_simple_alert_definition.meta.i18n_title
end

-- #######################################################

return flow_risk_simple_alert_definition
