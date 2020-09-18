--
-- (C) 2019-20 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")

local script = {
  -- Script category
  category = user_scripts.script_categories.security,

  -- This module is enabled by default
  default_enabled = true,

  -- This script is only for alerts generation
  is_alert = true,

  -- The default threshold value. The format is specific of the
  -- "threshold_cross" input builder
  default_value = {
    -- "> 30"
    operator = "gt",
    threshold = 256,
  },

  -- See below
  hooks = {},

  -- Allow user script configuration from the GUI
  gui = {
    -- Localization strings, from the "locales" directory of the plugin
    i18n_title = "entity_thresholds.syn_scan_victim_title",
    i18n_description = "entity_thresholds.syn_scan_victim_description",

    -- The input builder to use to draw the gui
    input_builder = "threshold_cross",

    -- Specific parameters of this input builder
    i18n_field_unit = user_scripts.field_units.syn_min,
    -- max allowed threshold value
    field_max = 65535,
    -- min allowed threshold value
    field_min = 1,
    -- threshold check operator. "gt" for ">", "lt" or "<"
    field_operator = "gt";
  }
}

-- #################################################################

-- Defines an hook which is executed every minute
function script.hooks.min(params)
  local sf = host.getSynScan()
  local value = sf["hits.syn_scan_victim"] or 0

  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_tcp_syn_scan, value)
end

-- #################################################################

return script
