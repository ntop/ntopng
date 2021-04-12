--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"


-- #################################################################

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  -- This script is only for alerts generation
  is_alert = true,

  default_value = {
    severity = alert_severities.notice,
  },

  gui = {
    i18n_title = "remote_access.title",
    i18n_description = "remote_access.description",
  }
}

-- #################################################################

return script
