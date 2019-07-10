--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")

local check_module = {
  key = "throughput",

  -- TODO gui specific parameters
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
