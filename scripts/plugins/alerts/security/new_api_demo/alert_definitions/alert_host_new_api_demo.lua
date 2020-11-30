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
   -- Call the paren constructor
   self.super:init()

   self.alert_type_params = {
      one_param = one_param,
      another_param = another_param
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_host_new_api_demo.format(ifid, alert, alert_type_params)
   local alert_consts = require("alert_consts")
   local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

   return i18n("new_api_demo.alert_host_new_api_demo_description",
	       {
		  host = entity,
		  one_param = alert_type_params.one_param,
		  another_param = alert_type_params.another_param
   })
end

-- #######################################################

return alert_host_new_api_demo
