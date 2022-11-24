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

local alert_custom_lua_script = classes.class(alert)

-- ##############################################

alert_custom_lua_script.meta = {
  alert_key = flow_alert_keys.flow_alert_custom_lua_script,
   i18n_title = "alerts_dashboard.alert_custom_lua_script",
  icon = "fas fa-fw fa-info-circle",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_custom_lua_script:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_custom_lua_script.format(ifid, alert, alert_type_params)
   return i18n("flow_details.custom_lua_script", { message = alert_type_params["alert.message"] } )
end

-- #######################################################

return alert_custom_lua_script

