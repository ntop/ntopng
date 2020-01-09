--
-- (C) 2019-20 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")

local script = {
  local_only = true,
  default_enabled = false,

  -- This script is only for alerts generation
  is_alert = true,

  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_thresholds_config.dns_traffic",
    i18n_description = "alerts_thresholds_config.alert_dns_description",
    i18n_field_unit = user_scripts.field_units.bytes,
    input_builder = "threshold_cross",
  },

  env = {
     dns_app_id = interface.getnDPIProtoId("DNS")
  }
}

-- #################################################################

function script.hooks.all(params)
  local value = alerts_api.host_delta_val(script.key, params.granularity, host.getApplicationBytes(script.env.dns_app_id)["bytes"])

  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_threshold_cross, value)
end

-- #################################################################

return script
