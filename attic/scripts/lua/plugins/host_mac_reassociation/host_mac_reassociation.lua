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

   alert_id = host_alert_keys.host_alert_normal,

   gui = {
      i18n_title = "alerts_thresholds_config.host_mac_reassociation_title",
      i18n_description = "alerts_thresholds_config.host_mac_reassociation_description",
      i18n_field_unit = checks.field_units.score,
   }
}

-- #################################################################

return score_threshold
