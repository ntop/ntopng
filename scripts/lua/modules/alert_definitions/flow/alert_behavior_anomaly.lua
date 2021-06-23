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
function alert_behavior_anomaly:init(entity, type_of_behavior, value, upper_bound, lower_bound, 
   ts_schema, page_path, timeserie_id --[[ This last 3 params are used to build up the href to the timeseries lately, if available ]])
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      entity = entity,
      type_of_behavior = type_of_behavior,
      value = value,
      upper_bound = upper_bound,
      lower_bound = lower_bound,
      ts_schema = ts_schema,
      page_path = page_path,
      timeserie_id = timeserie_id,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_behavior_anomaly.format(ifid, alert, alert_type_params)
   local href = ""
   local type_of_behavior = ""
   
   -- Name of the behavior type, e.g. Score
   if alert_type_params.type_of_behavior then
      type_of_behavior = i18n("alert_behaviors." .. alert_type_params.type_of_behavior)
   end

   -- Generating the href for the timeserie
   if ntop.isEnterpriseL() then
      if alert_type_params["ts_schema"] and alert_type_params["page_path"] and alert_type_params["timeserie_id"] then
         local alert_time = tonumber(alert.tstamp)
         -- 10 minutes before and 10 minutes after the alert
         local curr_time = '&epoch_begin=' .. tonumber(alert_time - 600) .. '&epoch_end=' .. tonumber(alert_time + 600)

         href = alert_type_params["page_path"] .. "?" .. alert_type_params["timeserie_id"] .. 
               "&page=historical&ts_schema=" .. alert_type_params["ts_schema"] .. "%3A" .. alert_type_params.type_of_behavior ..
               "&zoom=30m" .. curr_time
      end
   end

   return(i18n("alerts_dashboard.unexpected_behavior_anomaly_description",
		{
		   entity = alert_type_params.entity or "",
		   type_of_behavior = type_of_behavior,
		   value = alert_type_params.value or 0,
		   lower_bound = alert_type_params.lower_bound or 0,
		   upper_bound = alert_type_params.upper_bound or 0,
         href = href,
		}))
end

-- #######################################################

return alert_behavior_anomaly