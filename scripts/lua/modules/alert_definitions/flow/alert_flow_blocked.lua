--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_flow_blocked = classes.class(alert)

-- ##############################################

alert_flow_blocked.meta = {
   alert_key = flow_alert_keys.flow_alert_flow_blocked,
   i18n_title = "flow_details.flow_blocked_by_bridge",
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_flow_blocked:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_flow_blocked.format(ifid, alert, alert_type_params)
   return i18n("flow_details.flow_blocked_by_bridge")
end

-- #######################################################

return alert_flow_blocked
