--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")

local script = {
  local_only = true,

  hooks = {
    all = alerts_api.threshold_check_function
  },

  gui = {
    i18n_title = "alerts_thresholds_config.p2p_traffic",
    i18n_description = "alerts_thresholds_config.alert_p2p_description",
    i18n_field_unit = user_scripts.field_units.bytes,
    input_builder = user_scripts.threshold_cross_input_builder,
  },

  env = {
     p2p_app_id = interface.getnDPICategoryId("FileSharing")
  }
}

-- #################################################################

function script.get_threshold_value(granularity, info)
  return alerts_api.host_delta_val(script.key, granularity, host.getCategoryBytes(script.env.p2p_app_id)["bytes"])
end

-- #################################################################

return script
