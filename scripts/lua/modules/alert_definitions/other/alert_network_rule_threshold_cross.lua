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

function alert_network_rule_threshold_cross:init(ifid, ifname ,metric, frequency, threshold, value, threshold_sign)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      ifid = ifid,
      ifname = ifname,
      metric = metric,
      frequency = frequency,
      threshold = threshold,
      value = value,
      threshold_sign = threshold_sign
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_network_rule_threshold_cross.format(ifid, alert, alert_type_params)
   return(i18n("alert_messages.traffic_interface_volume_alert", {
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. alert_type_params.ifid,
    iface = alert_type_params.ifname,
    metric = alert_type_params.metric,
    value = alert_type_params.value,
    threshold_sign = alert_type_params.threshold_sign,
    threshold = alert_type_params.threshold,
    frequency = alert_type_params.frequency
  }))
end

-- #######################################################

return alert_network_rule_threshold_cross
