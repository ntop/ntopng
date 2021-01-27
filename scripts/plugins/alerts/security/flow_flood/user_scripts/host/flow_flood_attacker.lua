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

  default_enabled = true,
  default_value = {
    -- "> 50"
    operator = "gt",
    threshold = 256,
    severity = alert_severities.error,
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
  local attacker = nil

  if value ~= 0 then
    attacker = params.alert_entity.alert_entity_val
  end

  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_flows_flood_attacker, value, attacker)
end

-- #################################################################

return script
