--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local check_module = {
  key = "p2p",
  alert_type = alert_consts.alert_types.threshold_cross,
  check_function = alerts_api.threshold_check_function,

  gui = {
    i18n_title = "alerts_thresholds_config.p2p_traffic",
    i18n_description = "alerts_thresholds_config.alert_p2p_description",
    i18n_field_unit = alert_consts.field_units.bytes,
    input_builder = alerts_api.threshold_cross_input_builder,
  }
}

-- #################################################################

function check_module.get_threshold_value(granularity, info)
  return alerts_api.interface_delta_val(check_module.key, granularity, alerts_api.category_bytes(info, "FileSharing"))
end

-- #################################################################

return check_module
