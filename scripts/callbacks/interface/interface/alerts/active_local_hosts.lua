--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")

local script = {
  key = "active_local_hosts",

  hooks = {
    all = alerts_api.threshold_check_function
  },

  gui = {
    i18n_title = "alerts_thresholds_config.active_local_hosts",
    i18n_description = "alerts_thresholds_config.active_local_hosts_threshold_descr",
    i18n_field_unit = user_scripts.field_units.hosts,
    input_builder = user_scripts.threshold_cross_input_builder,
  }
}

-- #################################################################

function script.get_threshold_value(granularity, info)
  return info["stats"]["local_hosts"]
end

-- #################################################################

return script
