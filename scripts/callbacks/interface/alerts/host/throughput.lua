--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local check_module = {
  key = "throughput",
  alert_type = alert_consts.alert_types.threshold_cross,

  gui = {
    title = "alerts_thresholds_config.throughput",
    subtitle = "alerts_thresholds_config.alert_throughput_description",
    field = {field_unit = alert_consts.field_units.mbits},
  }
}

-- #################################################################

function check_module.check_function(granularity, host_key, info, threshold_config)
  local current_value = alerts_api.host_delta_val(metric_name, granularity, info["bytes.sent"] + info["bytes.rcvd"]) * 8 / granularity2sec(granularity)

  return(alerts_api.check_threshold_cross(
    granularity, check_module.key,
    alerts_api.hostAlertEntity(host_key),
    current_value, threshold_config
  ))
end

-- #################################################################

return check_module
