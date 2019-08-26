--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local check_module = {
  key = "too_many_flows",
  str_granularity = "min",
  always_enabled = true,
  check_function = alerts_api.anomaly_check_function,
  anomaly_type_builder = alerts_api.misconfiguredAppType,
}

-- #################################################################

return check_module
