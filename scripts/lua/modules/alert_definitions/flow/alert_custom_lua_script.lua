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

return alert_custom_lua_script

