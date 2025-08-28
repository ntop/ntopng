--
-- (C) 2019-25 - ntop.org
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

local alert_asn_rule_threshold_crossed = classes.class(alert)

alert_asn_rule_threshold_crossed.meta = {
  alert_key = other_alert_keys.alert_asn_rule_threshold_crossed,
  i18n_title = "show_alerts.host_pool_rule_threshold_cross",
  icon = "fas fa-fw fa-exclamation-triangle",
  entities = {
     alert_entities.as,
  },
}

-- ##############################################

function alert_asn_rule_threshold_crossed:init(ifid, asn, metric, metric_label, frequency, threshold, value, threshold_sign, metric_type)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      ifid = ifid,
      asn = asn,
      metric = metric,
      metric_label = metric_label,
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
function alert_asn_rule_threshold_crossed.format(ifid, alert, alert_type_params)
   
   if(alert_type_params.frequency == "5min") then
      alert_type_params.frequency = i18n("edit_check.hooks_name.5mins")
   elseif(alert_type_params.frequency == "hour") then
      alert_type_params.frequency = i18n("edit_check.hooks_name.hour")
   else
      alert_type_params.frequency = i18n("edit_check.hooks_name.day")
   end

   if(alert_type_params.metric == "asn:traffic" or 
             alert_type_params.metric == "asn:traffic_rcvd" or
             alert_type_params.metric == "asn:traffic_sent") then
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
    if alert_type_params.metric_label ~= nil then
        return(i18n("alert_messages.traffic_asn_volume_alert", {
            metric = alert_type_params.metric_label,
            value = alert_type_params.value,
            threshold_sign = alert_type_params.threshold_sign,
            threshold = alert_type_params.threshold,
            frequency = alert_type_params.frequency
        }))
    else
        return(i18n("alert_messages.traffic_asn_volume_alert_no_metric", {
            value = alert_type_params.value,
            threshold_sign = alert_type_params.threshold_sign,
            threshold = alert_type_params.threshold,
            frequency = alert_type_params.frequency
        }))
    end
end

-- #######################################################

return alert_asn_rule_threshold_crossed
