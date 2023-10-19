--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")

local script = {
  -- Script category
  category = user_scripts.script_categories.internals,

  default_enabled = true,
  anomaly_type_builder = alerts_api.slowStatsUpdateType,

  -- This script is only for alerts generation
  is_alert = true,

  hooks = {
    min = alerts_api.anomaly_check_function,
  },

  gui = {
    i18n_title = "alerts_dashboard.slow_stats_update",
    i18n_description = "alerts_dashboard.slow_stats_update_description",
  },
}

-- #################################################################

return script
