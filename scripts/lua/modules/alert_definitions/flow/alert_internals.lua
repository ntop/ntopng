--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_internals = classes.class(alert)

-- ##############################################

alert_internals.meta = {
  alert_key = flow_alert_keys.flow_alert_internals,
  i18n_title = "flow_checks_config.not_purged",
  icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_internals:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

return alert_internals
