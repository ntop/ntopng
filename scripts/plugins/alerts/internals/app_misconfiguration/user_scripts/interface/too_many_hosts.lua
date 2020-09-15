--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local script = {
  -- Script category
  category = user_scripts.script_categories.internals,

  always_enabled = true,
  anomaly_type_builder = alert_consts.alert_types.alert_misconfigured_app.create,

  -- This script is only for alerts generation
  is_alert = true,

  hooks = {
    min = alerts_api.anomaly_check_function,
  },

  gui = {
    i18n_title = "alerts_dashboard.too_many_hosts",
    i18n_description = "alerts_dashboard.too_many_hosts_description",
  },
}

-- #################################################################

return script
