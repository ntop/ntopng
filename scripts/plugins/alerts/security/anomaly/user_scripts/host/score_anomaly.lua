--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"

local script = {
  -- Script category
  category = user_scripts.script_categories.security,

  default_enabled = true,

  -- This script is only for alerts generation
  is_alert = true,

  default_value = {
    severity = alert_severities.warning,
  },

  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_thresholds_config.score_anomaly_title",
    i18n_description = "alerts_thresholds_config.score_anomaly_description",
  }
}

-- #################################################################

function script.hooks.min(params)
   -- TODO: remove, implemented in C++
end

-- #################################################################

return script
