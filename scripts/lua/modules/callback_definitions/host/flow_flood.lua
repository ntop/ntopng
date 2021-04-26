--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local flow_flood = {
   -- Script category
   category = user_scripts.script_categories.security,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_flow_flood,

   default_value = {
      -- "> 50"
      operator = "gt",
      threshold = 256,
      severity = alert_severities.error,
   },

   gui = {
      i18n_title = "entity_thresholds.flow_flood_title",
      i18n_description = "entity_thresholds.flow_flood_description",
      i18n_field_unit = user_scripts.field_units.flow_sec,
      input_builder = "threshold_cross",
      field_max = 65535,
      field_min = 1,
      field_operator = "gt";
   }
}

-- #################################################################

return flow_flood
