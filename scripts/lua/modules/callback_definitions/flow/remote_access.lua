--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
  -- Script category
  category = checks.check_categories.network,

  -- This script is only for alerts generation
  alert_id = flow_alert_keys.flow_alert_remote_access,

  default_value = {
  },

  gui = {
    i18n_title = "alerts_dashboard.remote_access_title",
    i18n_description = "alerts_dashboard.remote_access_description",
  }
}

-- #################################################################

return script
