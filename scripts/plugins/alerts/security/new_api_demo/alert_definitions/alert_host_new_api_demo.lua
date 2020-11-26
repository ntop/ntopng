--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local NewHostAlert = classes.class(alert)

-- ##############################################

NewHostAlert.meta = {
   alert_key = alert_keys.user.alert_user_04,
   i18n_title = "New Host API Demo",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function NewHostAlert:init(one_param, another_param)
   -- Optional, call to the `alert` constructor
   self.super:init()

   self.alert_type_params = {
      one_param = one_param,
      another_param = another_param
   }
end

-- #######################################################

function NewHostAlert:format()
   -- tprint("new format: "..self.def_script.alert_key)
end

-- #######################################################

return NewHostAlert
