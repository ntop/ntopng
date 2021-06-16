--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local score_anomaly = {
   -- Script category
   category = checks.script_categories.security,

   default_enabled = true,
   alert_id = host_alert_keys.host_alert_score_anomaly,

   default_value = {
   },

   gui = {
      i18n_title = "alerts_thresholds_config.score_anomaly_title",
      i18n_description = "alerts_thresholds_config.score_anomaly_description",
   }
}

-- #################################################################

return score_anomaly
