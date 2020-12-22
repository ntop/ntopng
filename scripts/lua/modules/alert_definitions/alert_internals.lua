--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"

local status_keys = require "status_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_internals = classes.class(alert)

-- ##############################################

alert_internals.meta = {
  status_key = status_keys.ntopng.status_not_purged,
  alert_key = alert_keys.ntopng.alert_internals,
  i18n_title = "flow_details.not_purged",
  icon = "fas fa-exclamation",
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
