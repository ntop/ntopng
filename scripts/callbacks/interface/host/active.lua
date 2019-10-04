--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local check_module = {
  key = "active",
  check_function = alerts_api.threshold_check_function,
  local_only = true,

  gui = {
    i18n_title = "alerts_thresholds_config.activity_time",
    i18n_description = "alerts_thresholds_config.alert_active_description",
    i18n_field_unit = alert_consts.field_units.seconds,
    input_builder = alerts_api.threshold_cross_input_builder,
  }
}

-- #################################################################

function check_module.get_threshold_value(granularity, info)
  return alerts_api.host_delta_val(check_module.key, granularity, info["total_activity_time"])
end

-- #################################################################

return check_module
