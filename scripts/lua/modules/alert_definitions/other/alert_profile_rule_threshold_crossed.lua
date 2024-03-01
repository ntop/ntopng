--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"
local format_utils = require "format_utils"

-- ##############################################

local alert_profile_rule_threshold_crossed = classes.class(alert)

alert_profile_rule_threshold_crossed.meta = {
  alert_key = other_alert_keys.alert_profile_rule_threshold_crossed,
  i18n_title = "show_alerts.host_pool_rule_threshold_cross",
  icon = "fas fa-fw fa-exclamation-triangle",
  entities = {
     alert_entities.system,
     alert_entities.interface,
  },
}

-- ##############################################

function alert_profile_rule_threshold_crossed:init(ifid, profile, metric, frequency, threshold, value, threshold_sign, metric_type)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      ifid = ifid,
      profile = profile,
      metric = metric,
      frequency = frequency,
      threshold = threshold,
      value = value,
      threshold_sign = threshold_sign,
      metric_type = metric_type
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_profile_rule_threshold_crossed.format(ifid, alert, alert_type_params)
   
   if(alert_type_params.frequency == "5min") then
      alert_type_params.frequency = i18n("edit_check.hooks_name.5mins")
   elseif(alert_type_params.frequency == "hour") then
      alert_type_params.frequency = i18n("edit_check.hooks_name.hour")
   else
      alert_type_params.frequency = i18n("edit_check.hooks_name.day")
   end

   if(alert_type_params.metric == "profile:traffic") then
      if(alert_type_params.metric_type == "volume") then
         alert_type_params.value = bytesToSize(alert_type_params.value)
         alert_type_params.threshold = bytesToSize(alert_type_params.threshold)
      elseif(alert_type_params.metric_type == "throughput") then
         alert_type_params.value = bitsToSize(alert_type_params.value)
         alert_type_params.threshold = bitsToSize(alert_type_params.threshold)
      elseif(alert_type_params.metric_type == "percentage") then
         alert_type_params.value = string.format("%s",tostring(round(alert_type_params.value, 2))) .. "%"
         alert_type_params.threshold = string.format("%s",tostring(alert_type_params.threshold)).. "%"
      end
    else 
        if(alert_type_params.metric_type == "percentage") then
            alert_type_params.value = string.format("%s",tostring(round(alert_type_params.value, 2))) .. "%"
            alert_type_params.threshold = string.format("%s",tostring(alert_type_params.threshold)).. "%"
        end
    end
   
    return(i18n("alert_messages.traffic_profile_volume_alert", {
        url = ntop.getHttpPrefix() .. "/lua/profile_details.lua?ifid="..ifid.."&profile=",
        profile = alert_type_params.profile,
        metric = alert_type_params.metric,
        value = alert_type_params.value,
        threshold_sign = alert_type_params.threshold_sign,
        threshold = alert_type_params.threshold,
        frequency = alert_type_params.frequency
        }))
  
end

-- #######################################################

return alert_profile_rule_threshold_crossed
