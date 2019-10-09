--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")

local check_module = {
  key = "bytes",

  hooks = {
    all = alerts_api.threshold_check_function
  },

  gui = {
    i18n_title = "alerts_thresholds_config.alert_bytes_title",
    i18n_description = "alerts_thresholds_config.alert_bytes_description",
    i18n_field_unit = user_scripts.field_units.bytes,
    input_builder = user_scripts.threshold_cross_input_builder,
  }
}

-- #################################################################

function check_module.get_threshold_value(granularity, info)
  return alerts_api.interface_delta_val(check_module.key, granularity, info["stats"]["bytes"])
end

-- #################################################################

return check_module
