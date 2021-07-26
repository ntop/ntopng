--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

local asn_connection = {
   -- Script category
   category = checks.check_categories.network,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_asn_connection,

   -- The default threshold value. The format is specific of the
   -- "threshold_cross" input builder
   default_value = {
      operator = "gt",
      threshold = 100,
   },

   -- Allow user script configuration from the GUI
   gui = {
      -- Localization strings, from the "locales" directory of the plugin
      i18n_title = "entity_thresholds.asn_connection_title",
      i18n_description = "entity_thresholds.asn_connection_description",

      -- The input builder to use to draw the gui
      input_builder = "threshold_cross",
      
      -- max allowed threshold value
      field_max = 65535,
      -- min allowed threshold value
      field_min = 1,
      -- threshold check operator. "gt" for ">", "lt" or "<"
      field_operator = "gt";
   }
}

-- #################################################################

return asn_connection
