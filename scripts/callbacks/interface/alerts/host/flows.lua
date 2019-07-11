--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local check_module = {
  key = "flows",
  alert_type = alert_consts.alert_types.threshold_cross,
  check_function = alerts_api.threshold_check_function,

  gui = {
    i18n_title = "flows",
    i18n_description = "alerts_thresholds_config.alert_flows_description",
    i18n_field_unit = alert_consts.field_units.flows,
    input_builder = alerts_api.threshold_cross_input_builder,
  }
}

-- #################################################################

function check_module.get_threshold_value(granularity, info)
  return alerts_api.host_delta_val(check_module.key, granularity, info["total_flows.as_client"] + info["total_flows.as_server"])
end

-- #################################################################

return check_module
