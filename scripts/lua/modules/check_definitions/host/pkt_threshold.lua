--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local pkt_threshold = {
   -- Script category
   category = checks.check_categories.network,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_pkt_threshold,

   default_value = {
      operator = "gt",
      threshold = 10000,
   },

   gui = {
      i18n_title = "alerts_thresholds_config.alert_pkt_title",
      i18n_description = "alerts_thresholds_config.alert_pkt_description",
      i18n_field_unit = checks.field_units.packets,
      input_builder = "threshold_cross",
      field_operator = "gt";
   },
}

-- #################################################################

return pkt_threshold
