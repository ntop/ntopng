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

local alert_flow_new_api_demo = classes.class(alert)

-- ##############################################

alert_flow_new_api_demo.meta = {
   status_key = status_keys.user.status_user_02, -- A flow status key
   alert_key = alert_keys.user.alert_user_02,
   i18n_title = "New Flow API Demo",
   icon = "fas fa-exclamation",
   status_always_notify = true, -- Optional, if true, a notification is always emitted even when the status is not predominant or every time flow.triggerStatus is called
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_flow_new_api_demo:init(one_flow_param, another_flow_param)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      one_flow_param = one_flow_param,
      another_flow_param = another_flow_param
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_flow_new_api_demo.format(ifid, alert, alert_type_params)
   return i18n("new_api_demo.alert_flow_new_api_demo_description",
	       {
		  one_flow_param = alert_type_params.one_flow_param,
		  another_flow_param = alert_type_params.another_flow_param
   })
end

-- #######################################################

return alert_flow_new_api_demo
