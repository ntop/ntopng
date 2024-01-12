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

local alert_cidr_rule_threshold_crossed = classes.class(alert)

alert_cidr_rule_threshold_crossed.meta = {
  alert_key = other_alert_keys.alert_cidr_rule_threshold_crossed,
  i18n_title = "show_alerts.network_rule_threshold_crossed",
  icon = "fas fa-fw fa-exclamation-triangle",
  entities = {
     alert_entities.system,
     alert_entities.network,
  },
}

-- ##############################################

function alert_cidr_rule_threshold_crossed:init(ifid, network ,metric, frequency, threshold, value, threshold_sign, metric_type, network_id)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      ifid = ifid,
      network = network,
      metric = metric,
      frequency = frequency,
      threshold = threshold,
      value = value,
      threshold_sign = threshold_sign,
      metric_type = metric_type,
      network_id = network_id
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_cidr_rule_threshold_crossed.format(ifid, alert, alert_type_params)
   
   if(alert_type_params.frequency == "5min") then
      alert_type_params.frequency = i18n("edit_check.hooks_name.5mins")
   elseif(alert_type_params.frequency == "hour") then
      alert_type_params.frequency = i18n("edit_check.hooks_name.hour")
   else
      alert_type_params.frequency = i18n("edit_check.hooks_name.day")
   end

   
    if alert_type_params.metric == "subnet:broadcast_traffic" or alert_type_params.metric == "subnet:broadcast_traffic-egress"  or alert_type_params.metric == "subnet:broadcast_traffic-ingress" or alert_type_params.metric == "subnet:traffic" or alert_type_params.metric == "subnet:traffic-egress" or alert_type_params.metric == "subnet:traffic-ingress" then 
      if (alert_type_params.metric_type == "volume") then
         alert_type_params.threshold  = format_utils.bytesToSize(alert_type_params.threshold)
         alert_type_params.value      = format_utils.bytesToSize(alert_type_params.value)
      elseif (alert_type_params.metric_type == "throughput") then
         alert_type_params.threshold  = tostring(format_utils.bitsToSize(alert_type_params.threshold))
         alert_type_params.value      = tostring(format_utils.bitsToSize(alert_type_params.value))
      else 
         alert_type_params.threshold  = tostring(round(alert_type_params.threshold, 2) .. "%")
         alert_type_params.value      = tostring(round(alert_type_params.value, 2) .. '%')
      end   

   else 
      if (alert_type_params.metric_type == "percentage") then
         alert_type_params.threshold  = tostring(round(alert_type_params.threshold, 2) .. "%")
         alert_type_params.value      = tostring(round(alert_type_params.value, 2) .. '%')
      end
   end

   if (alert_type_params.metric == "subnet:rtt" and alert_type_params.metric_type ~= "percentage") then
      alert_type_params.threshold  = alert_type_params.threshold.." ms"
      alert_type_params.value      = alert_type_params.value.." ms"
   end
   
    return(i18n("alert_messages.traffic_network_volume_alert", {
        url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?network=",
        network = alert_type_params.network,
        network_id = alert_type_params.network_id,
        host_pool_label = alert_type_params.host_pool_label,
        metric = alert_type_params.metric,
        value = alert_type_params.value,
        threshold_sign = alert_type_params.threshold_sign,
        threshold = alert_type_params.threshold,
        frequency = alert_type_params.frequency
        }))
  
end

-- #######################################################

return alert_cidr_rule_threshold_crossed
