--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local flows_anomaly = {
  -- Script category
   category = user_scripts.script_categories.network,

   alert_id = host_alert_keys.host_alert_flows_anomaly,

  default_value = {
    severity = alert_severities.warning,
  },

  gui = {
    i18n_title = "alerts_thresholds_config.flows_anomaly_title",
    i18n_description = "alerts_thresholds_config.flows_anomaly_description",
  }
}

-- #################################################################

return flows_anomaly
