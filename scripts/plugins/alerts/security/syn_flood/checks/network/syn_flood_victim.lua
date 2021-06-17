--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local checks = require("checks")

local script = {
  packet_interface_only = true,
  
  -- Script category
  category = checks.check_categories.security,

  default_enabled = false,

  default_value = {
     operator = "gt",
     threshold = 32768,
  },

  -- See below
  hooks = {},


  gui = {
    i18n_title = "entity_thresholds.syn_victim_title",
    i18n_description = "entity_thresholds.syn_victim_description",
    i18n_field_unit = checks.field_units.syn_sec,
    input_builder = "threshold_cross",
    field_max = 65535,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

function script.hooks.min(params)
  local value = params.entity_info["hits.syn_flood_victim"] or 0
  local victim = nil

  if value ~= 0 then
    victim = params.alert_entity.entity_val
  end

  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_tcp_syn_flood_victim, value, nil, victim)
end

-- #################################################################

return script
