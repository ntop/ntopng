--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local script = {
  always_enabled = true,
  anomaly_type_builder = alerts_api.misconfiguredAppType,

  -- This script is only for alerts generation
  is_alert = true,

  hooks = {
    min = alerts_api.anomaly_check_function,
  }
}

-- #################################################################

return script
