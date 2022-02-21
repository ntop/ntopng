--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

local script = {
  -- Script category
  category = checks.check_categories.security,
  
  -- This module is disabled by default
  default_enabled = false,

  alert_id = host_alert_keys.host_alert_scan_detected,
  
  default_value = {
     operator = "gt",
     threshold = 32,
  },

  -- See below
  hooks = {},

  -- Allow user script configuration from the GUI
  gui = {
    i18n_title = "entity_thresholds.scan_detection_title",
    i18n_description = "entity_thresholds.scan_detection_description",

    -- The input builder to use to draw the gui
    input_builder = "threshold_cross",

    -- Specific parameters of this input builder
    i18n_field_unit = checks.field_units.flows,
    -- max allowed threshold value
    field_max = 65535,
    -- min allowed threshold value
    field_min = 1,
    -- threshold check operator. "gt" for ">", "lt" or "<"
    field_operator = "gt";
  }
}

-- #################################################################

return script
