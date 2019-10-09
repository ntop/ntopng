--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")

local check_module = {
  key = "idle",
  local_only = true,

  hooks = {
    all = alerts_api.threshold_check_function
  },

  gui = {
    i18n_title = "alerts_thresholds_config.idle_time",
    i18n_description = "alerts_thresholds_config.alert_idle_description",
    i18n_field_unit = user_scripts.field_units.seconds,
    input_builder = user_scripts.threshold_cross_input_builder,
  }
}

-- #################################################################

function check_module.get_threshold_value(granularity, info)
  return alerts_api.host_delta_val(check_module.key, granularity, os.time() - info["seen.last"])
end

-- #################################################################

return check_module
