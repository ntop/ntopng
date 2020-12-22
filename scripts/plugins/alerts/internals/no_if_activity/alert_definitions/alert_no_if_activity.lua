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

local alert_no_if_activity = classes.class(alert)

-- ##############################################

alert_no_if_activity.meta = {  
alert_key = alert_keys.ntopng.alert_no_if_activity,
i18n_title = "no_if_activity.alert_no_activity_title",
icon = "fas fa-arrow-circle-up",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function alert_no_if_activity:init(one_param, another_param)
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
function alert_no_if_activity.format(ifid, alert, alert_type_params)
  i18n("no_if_activity.status_no_activity_description")
end

-- #######################################################

return alert_no_if_activity
