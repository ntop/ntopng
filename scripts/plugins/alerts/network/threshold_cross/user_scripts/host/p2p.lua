--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  local_only = true,
  default_enabled = false,

  -- This script is only for alerts generation
  is_alert = true,

  default_value = {
    operator = "gt",
    severity = alert_severities.error,
  },

  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_thresholds_config.p2p_traffic",
    i18n_description = "alerts_thresholds_config.alert_p2p_description",
    i18n_field_unit = user_scripts.field_units.bytes,
    input_builder = "threshold_cross",
    field_operator = "gt";
  },
}

-- #################################################################

function script.hooks.min(params)
   -- TODO: remove, implemented in C++
end

-- #################################################################

return script
