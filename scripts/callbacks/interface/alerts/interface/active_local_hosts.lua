--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local check_module = {
  key = "active_local_hosts",
  alert_type = alert_consts.alert_types.threshold_cross,
  check_function = alerts_api.threshold_check_function,

  gui = {
    i18n_title = "alerts_thresholds_config.active_local_hosts",
    i18n_description = "alerts_thresholds_config.active_local_hosts_threshold_descr",
    i18n_field_unit = alert_consts.field_units.hosts,
    input_builder = alerts_api.threshold_cross_input_builder,
  }
}

-- #################################################################

function check_module.get_threshold_value(granularity, info)
  return info["stats"]["local_hosts"]
end

-- #################################################################

return check_module
