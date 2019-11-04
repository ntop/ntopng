--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")

local script = {
  local_only = true,

  hooks = {
    all = alerts_api.threshold_check_function
  },

  gui = {
    i18n_title = "alerts_thresholds_config.throughput",
    i18n_description = "alerts_thresholds_config.alert_throughput_description",
    i18n_field_unit = user_scripts.field_units.mbits,
    input_builder = user_scripts.threshold_cross_input_builder,
  }
}

-- #################################################################

function script.get_threshold_value(granularity, info)
  local host_bytes = host.getBytes()

  return alerts_api.host_delta_val(script.key, granularity, host_bytes["bytes.sent"] + host_bytes["bytes.rcvd"]) * 8 / granularity2sec(granularity)
end

-- #################################################################

return script
