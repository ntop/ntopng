--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local alert_consts = require("alert_consts")
local host_alert_keys = require "host_alert_keys"

local fin_scan = {
   -- Script category
   category = checks.check_categories.network,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_fin_scan,
   severity = alert_consts.get_printable_severities().error,

   -- The default threshold value. The format is specific of the
   -- "threshold_cross" input builder
   default_value = {
      operator = "gt",
      threshold = 256,
   },

   -- Allow user script configuration from the GUI
   gui = {
      i18n_title = "alerts_dashboard.tcp_fin_scan",
      i18n_description = "entity_thresholds.fin_scan_description",

      -- The input builder to use to draw the gui
      input_builder = "threshold_cross",

      -- Specific parameters of this input builder
      i18n_field_unit = checks.field_units.fin_min,
      -- max allowed threshold value
      field_max = 65535,
      -- min allowed threshold value
      field_min = 1,
      -- threshold check operator. "gt" for ">", "lt" or "<"
      field_operator = "gt";
   }
}

-- #################################################################

return fin_scan
