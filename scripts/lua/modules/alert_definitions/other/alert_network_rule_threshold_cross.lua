--
-- (C) 2019-22 - ntop.org
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

local alert_network_rule_threshold_cross = classes.class(alert)

alert_network_rule_threshold_cross.meta = {
  alert_key = other_alert_keys.alert_network_rule_threshold_cross,
  i18n_title = "show_alerts.network_interface_rule_threshold_cross",
  icon = "fas fa-fw fa-exclamation-triangle",
  entities = {
     alert_entities.system,
     alert_entities.interface,
  },
}

-- ##############################################

function alert_network_rule_threshold_cross:init(ifid, ifname ,metric, frequency, threshold, value, threshold_sign, metric_type, host)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      ifid = ifid,
      ifname = ifname,
      metric = metric,
      frequency = frequency,
      threshold = threshold,
      value = value,
      threshold_sign = threshold_sign,
      metric_type = metric_type,
      host = host
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_network_rule_threshold_cross.format(ifid, alert, alert_type_params)
   
   if(alert_type_params.frequency == "5min") then
      alert_type_params.frequency = i18n("edit_check.hooks_name.5mins")
   elseif(alert_type_params.frequency == "hour") then
      alert_type_params.frequency = i18n("edit_check.hooks_name.hour")
   else
      alert_type_params.frequency = i18n("edit_check.hooks_name.day")
   end

   if(alert_type_params.metric == "iface:traffic" 
      or alert_type_params.metric == "iface:traffic_rxtx"
      or alert_type_params.metric == "iface:traffic_rxtx-rx"
      or alert_type_params.metric == "iface:traffic_rxtx-tx"
      or alert_type_params.metric == "flowdev:traffic"
      or alert_type_params.metric == "flowdev_port:traffic") then
      if(alert_type_params.metric_type == "volume") then
         alert_type_params.value = bytesToSize(alert_type_params.value)
         alert_type_params.threshold = bytesToSize(alert_type_params.threshold)
      elseif(alert_type_params.metric_type == "throughput") then
         alert_type_params.value = bitsToSize(alert_type_params.value)
         alert_type_params.threshold = bitsToSize(alert_type_params.threshold)
      else
         alert_type_params.value = string.format("%s",tostring(round(alert_type_params.value, 2))) .. "%"
         alert_type_params.threshold = string.format("%s",tostring(alert_type_params.threshold)).. "%"
      end
   end

   tprint("HERE IN ALERT FORMAT")
   
   if( alert_type_params.metric ~= "flowdev:traffic" and alert_type_params.metric ~= "flowdev_port:traffic" )then
      return(i18n("alert_messages.traffic_interface_volume_alert", {
         url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. alert_type_params.ifid,
         iface = alert_type_params.ifname,
         metric = alert_type_params.metric,
         value = alert_type_params.value,
         threshold_sign = alert_type_params.threshold_sign,
         threshold = alert_type_params.threshold,
         frequency = alert_type_params.frequency
      }))
  elseif (alert_type_params.metric == "flowdev:traffic") then 
      return(i18n("alert_messages.traffic_flowdev_volume_alert", {
         url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/flowdevice_details.lua?ip=" .. alert_type_params.host,
         host = alert_type_params.host,
         metric = alert_type_params.metric,
         value = alert_type_params.value,
         threshold_sign = alert_type_params.threshold_sign,
         threshold = alert_type_params.threshold,
         frequency = alert_type_params.frequency
      }))
  else
   tprint("HERE")
      return(i18n("alert_messages.traffic_flowdev_port_volume_alert", {
            url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/flowdevice_details.lua?ip=" .. alert_type_params.host,
            iface = alert_type_params.ifname,
            host = alert_type_params.host,
            metric = alert_type_params.metric,
            value = alert_type_params.value,
            threshold_sign = alert_type_params.threshold_sign,
            threshold = alert_type_params.threshold,
            frequency = alert_type_params.frequency
         }))
  end
end

-- #######################################################

return alert_network_rule_threshold_cross
