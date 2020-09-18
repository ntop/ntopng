--
-- (C) 2019-20 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")

local script = {
  -- Script category
  category = user_scripts.script_categories.security,

  default_enabled = true,
  default_value = {
    -- "> 50"
    operator = "gt",
    threshold = 256,
  },

  -- This script is only for alerts generation
  is_alert = true,

  -- See below
  hooks = {},

  gui = {
    i18n_title = "entity_thresholds.flow_attacker_title",
    i18n_description = "entity_thresholds.flow_attacker_description",
    i18n_field_unit = user_scripts.field_units.flow_sec,
    input_builder = "threshold_cross",
    field_max = 65535,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

function script.hooks.min(params)
  local ff = host.getFlowFlood()
  local value = ff["hits.flow_flood_attacker"] or 0

  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_flows_flood, value)
end

-- #################################################################

return script
