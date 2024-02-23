--
-- (C) 2019-24 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
  default_enabled = false,

  -- Script category
  category = checks.check_categories.security, 

  alert_id = flow_alert_keys.flow_alert_custom_lua_script,

  gui = {
    i18n_title = "flow_checks_config.custom_lua_script",
    i18n_description = "flow_checks_config.custom_lua_script_description",
  }
}

-- #################################################################

return script
