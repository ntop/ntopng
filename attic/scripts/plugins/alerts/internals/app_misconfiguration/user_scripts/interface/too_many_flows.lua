--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local alert_severities = require "alert_severities"

local script = {
  -- Script category
  category = user_scripts.script_categories.internals,

  always_enabled = true,
  anomaly_type_builder = alert_consts.alert_types.alert_misconfigured_app.new,

  -- This script is only for alerts generation
  is_alert = true,

  default_value = {
    severity = alert_severities.warning,
  },

  hooks = {
    min = alerts_api.anomaly_check_function,
  },

  gui = {
    i18n_title = "alerts_dashboard.too_many_flows",
    i18n_description = "alerts_dashboard.too_many_flows_description",
  },
}

-- #################################################################

return script
