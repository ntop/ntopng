--
-- (C) 2019-20 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  local_only = true,
  default_enabled = false,

  -- This script is only for alerts generation
  is_alert = true,

  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_thresholds_config.throughput",
    i18n_description = "alerts_thresholds_config.alert_throughput_description",
    i18n_field_unit = user_scripts.field_units.mbits,
    input_builder = "threshold_cross",
  }
}

-- #################################################################

function script.hooks.all(params)
  local host_bytes = host.getBytes()
  local value = alerts_api.host_delta_val(script.key, params.granularity, host_bytes["bytes.sent"] + host_bytes["bytes.rcvd"]) * 8 / granularity2sec(params.granularity)

  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_threshold_cross, value)
end

-- #################################################################

return script
