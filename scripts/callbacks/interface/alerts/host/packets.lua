--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local check_module = {
  key = "packets",
  alert_type = alert_consts.alert_types.threshold_cross,

  gui = {
    title = "packets",
    subtitle = "alerts_thresholds_config.alert_packets_description",
    field = {field_unit = alert_consts.field_units.packets},
  }
}

-- #################################################################

function check_module.check_function(granularity, host_key, info, threshold_config)
  local current_value = alerts_api.host_delta_val(check_module.key, granularity, info["packets.sent"] + info["packets.rcvd"])

  return(alerts_api.check_threshold_cross(
    granularity, check_module.key,
    alerts_api.hostAlertEntity(host_key),
    current_value, threshold_config
  ))
end

-- #################################################################

return check_module
