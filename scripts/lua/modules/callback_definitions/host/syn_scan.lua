--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

local syn_scan = {
   -- Script category
   category = checks.check_categories.network,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_syn_scan,

   -- The default threshold value. The format is specific of the
   -- "threshold_cross" input builder
   default_value = {
      operator = "gt",
      threshold = 256,
   },

   -- Allow user script configuration from the GUI
   gui = {
      -- Localization strings, from the "locales" directory of the plugin
      i18n_title = "entity_thresholds.syn_scan_title",
      i18n_description = "entity_thresholds.syn_scan_description",

      -- The input builder to use to draw the gui
      input_builder = "threshold_cross",

      -- Specific parameters of this input builder
      i18n_field_unit = checks.field_units.syn_min,
      -- max allowed threshold value
      field_max = 65535,
      -- min allowed threshold value
      field_min = 1,
      -- threshold check operator. "gt" for ">", "lt" or "<"
      field_operator = "gt";
   }
}

-- #################################################################

return syn_scan
