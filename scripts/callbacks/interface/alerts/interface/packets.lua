--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local check_module = {
  key = "packets",
  alert_type = alert_consts.alert_types.threshold_cross,
  check_function = alerts_api.threshold_check_function,

  gui = {
    i18n_title = "packets",
    i18n_description = "alerts_thresholds_config.alert_packets_description",
    i18n_field_unit = alert_consts.field_units.packets,
    input_builder = alerts_api.threshold_cross_input_builder,
  }
}

-- #################################################################

function check_module.get_threshold_value(granularity, info)
  return alerts_api.interface_delta_val(check_module.key, granularity, info["stats"]["packets"])
end

-- #################################################################

return check_module
