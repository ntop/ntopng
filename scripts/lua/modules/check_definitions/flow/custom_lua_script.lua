--
-- (C) 2019-26 - ntop.org
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

-- In development: hidden unless enabled (same key as CUSTOM_FLOW_SCRIPTS_ENABLED_KEY in ntop_defines.h)
function script.setup()
   return(ntop.getCache("ntopng.devel.custom_flow_scripts_enabled") == "1")
end

-- #################################################################

return script
