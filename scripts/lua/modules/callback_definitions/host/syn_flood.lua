--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"

-- #################################################################

local syn_flood = {
   -- Script category
   category = user_scripts.script_categories.security,

   default_enabled = false,

   default_value = {
      operator = "gt",
      threshold = 256,
      severity = alert_severities.error,
   },

   gui = {
      i18n_title = "entity_thresholds.syn_flood_title",
      i18n_description = "entity_thresholds.syn_flood_description",
      i18n_field_unit = user_scripts.field_units.syn_sec,
      input_builder = "threshold_cross",
      field_max = 65535,
      field_min = 1,
      field_operator = "gt";
   }
}

-- #################################################################

return syn_flood
