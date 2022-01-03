--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local score_threshold = {
   -- Script category
   category = checks.check_categories.security,

   default_enabled = true,

   alert_id = host_alert_keys.host_alert_score_threshold,

   default_value = {
      operator = "gt",
      threshold = 5000,
   },

   gui = {
      i18n_title = "alerts_thresholds_config.score_threshold_title",
      i18n_description = "alerts_thresholds_config.score_threshold_description",
      i18n_field_unit = checks.field_units.score,
      input_builder = "threshold_cross",
      field_max = 20000,
      field_min = 1,
      field_operator = "gt";
   }
}

-- #################################################################

return score_threshold
