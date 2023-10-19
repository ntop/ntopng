--
-- (C) 2019-22 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local checks = require("checks")

local script = {
  -- Script category
  category = checks.check_categories.network,

  default_enabled = false,
  severity = alert_consts.get_printable_severities().error,

  default_value = {
    operator = "gt",
    threshold = 1073741824, -- 1GB
  },

  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_thresholds_config.inner_traffic",
    i18n_description = "alerts_thresholds_config.alert_network_inner_description",
    i18n_field_unit = checks.field_units.bytes,
    input_builder = "threshold_cross",
  }
}

-- #################################################################

function script.hooks.min(params)
  local value = alerts_api.network_delta_val(script.key, params.granularity, params.entity_info["inner"])

  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_threshold_cross, value)
end

-- #################################################################

return script
