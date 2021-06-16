--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local alerts_api = require "alerts_api"
local alert_consts = require("alert_consts")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
  -- Script category
  category = checks.check_categories.security,

  -- This script is only for alerts generation
  alert_id = flow_alert_keys.flow_alert_web_mining,

  default_value = {
    items = {},
  },

  gui = {
    i18n_title = "flow_checks_config.web_mining",
    i18n_description = "flow_checks_config.web_mining_description",
  }
}

-- #################################################################

return script
