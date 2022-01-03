--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local icmp_flood = {
   -- Script category
   category = checks.check_categories.security,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_icmp_flood,

   default_value = {
      operator = "gt",
      threshold = 256,
   },

   gui = {
      i18n_title = "entity_thresholds.icmp_flood_title",
      i18n_description = "entity_thresholds.icmp_flood_description",
      i18n_field_unit = checks.field_units.icmp_flow_sec,
      input_builder = "threshold_cross",
      field_max = 65535,
      field_min = 1,
      field_operator = "gt";
   }
}

-- #################################################################

return icmp_flood
