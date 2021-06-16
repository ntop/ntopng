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

  alert_id = flow_alert_keys.flow_alert_remote_to_remote,

  default_enabled = false,

  default_value = {
  },

  gui = {
    i18n_title = "flow_checks_config.remote_to_remote",
    i18n_description = "flow_checks_config.remote_to_remote_description",
  }
}

-- #################################################################

return script
