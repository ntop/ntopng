--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"

local script = {
  -- Script category
  category = user_scripts.script_categories.security,

  -- This module is disabled by default
  default_enabled = false,

  -- This script is only for alerts generation
  is_alert = true,

  default_value = {
     operator = "gt",
     threshold = 32768,
     severity = alert_severities.error,
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
  local value = params.entity_info["hits.syn_scan_victim"] or 0
  local victim = nil

  if value ~= 0 then
    victim = params.alert_entity.alert_entity_val
  end
  
  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_tcp_syn_scan_victim, value, nil, victim)
end

-- #################################################################

return script
