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

local alert_host_new_api_demo = classes.class(alert)

-- ##############################################

alert_host_new_api_demo.meta = {
   alert_key = alert_keys.user.alert_user_04,
   i18n_title = "New Host API Demo",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function alert_host_new_api_demo:init(one_param, another_param)
   self.super:init()

   self.alert_type_params = {
      one_param = one_param,
      another_param = another_param
   }
end

-- #######################################################

function alert_host_new_api_demo:format()
   -- tprint("new format: "..self.def_script.alert_key)
end

-- #######################################################

return alert_host_new_api_demo
