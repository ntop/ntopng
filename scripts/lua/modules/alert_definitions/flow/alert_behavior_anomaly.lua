--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
local classes = require "classes"
local alert = require "alert"

-- ##############################################

local alert_behavior_anomaly = classes.class(alert)

local i18n_title = i18n("alerts_dashboard.alert_unexpected_behavior_title", {type = ""})

-- ##############################################

alert_behavior_anomaly.meta = {
   alert_key = other_alert_keys.alert_behavior_anomaly,
   i18n_title = i18n_title,
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param value       The value got from the measurement
-- @param lower_bound The lower bound of the measurement
-- @param upper_bound The upper bound of the measurement
-- @return A table with the alert built
function alert_behavior_anomaly:init(entity, type_of_behaviour, value, upper_bound, lower_bound, href)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
         entity = entity,
         type_of_behaviour = type_of_behaviour,
         value = value,
         upper_bound = upper_bound,
         lower_bound = lower_bound,
         href = href,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_behavior_anomaly.format(ifid, alert, alert_type_params)
   return(i18n("alerts_dashboard.unexpected_behavior_anomaly_description",
		{
		   entity = alert_type_params.entity or "",
		   type_of_behaviour = alert_type_params.type_of_behaviour or "",
		   value = alert_type_params.value or 0,
		   lower_bound = alert_type_params.lower_bound or 0,
		   upper_bound = alert_type_params.upper_bound or 0,
         href = alert_type_params.href or "",
		}))
end

-- #######################################################

return alert_behavior_anomaly