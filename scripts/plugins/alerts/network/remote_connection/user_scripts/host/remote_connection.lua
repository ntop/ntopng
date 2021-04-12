--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  default_enabled = true,

  -- This script is only for alerts generation
  is_alert = true,

  -- See below
  hooks = {},

  default_value = {
   severity = alert_severities.notice,
  },
  
  gui = {
    i18n_title = "alerts_dashboard.remote_connection_title",
    i18n_description = "alerts_dashboard.remote_connection_description",
  }
}

-- #################################################################

function script.hooks.min(params)
   -- TODO: remove, implemented in C++
end

-- #################################################################

return script
