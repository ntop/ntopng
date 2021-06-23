--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
local classes = require "classes"
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_contacts_anomaly = classes.class(alert)

-- ##############################################

alert_contacts_anomaly.meta = {
   alert_key = other_alert_keys.alert_contacts_anomaly,
   i18n_title = "alerts_dashboard.unexpected_host_behaviour_contacts_title",
   icon = "fas fa-fw fa-exclamation",
   entities = {},
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param value       The value got from the measurement
-- @param prediction  The value instead predicted
-- @param lower_bound The lower bound of the measurement
-- @param upper_bound The upper bound of the measurement
-- @return A table with the alert built
function alert_contacts_anomaly:init(value, prediction, upper_bound, lower_bound)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      value = value,
      prediction = prediction,
      upper_bound = upper_bound,
      lower_bound = lower_bound,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_contacts_anomaly.format(ifid, alert, alert_type_params)
   local alert_consts = require("alert_consts")
   
   return(i18n("alerts_dashboard.unexpected_host_behavior_description",
		{
		   host = firstToUpper(alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["entity_id"]), alert["entity_val"])),
		   type_of_behaviour = i18n("alert.anomalies.contacts") or "",
		   value = alert_type_params.value,
		   prediction = alert_type_params.prediction or 0,
		   lower_bound = alert_type_params.lower_bound or 0,
		   upper_bound = alert_type_params.upper_bound or 0,
		}))
end

-- #######################################################

return alert_contacts_anomaly
