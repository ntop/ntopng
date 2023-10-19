--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"
local alert_consts = require("alert_consts")

-- #################################################################

local p2p = {
  -- Script category
  category = checks.check_categories.network,
  severity = alert_consts.get_printable_severities().error,

  default_enabled = false,
  alert_id = host_alert_keys.host_alert_custom_lua_script,

  default_value = {
  },

  gui = {
     i18n_title = "alerts_thresholds_config.custom_host_lua_script_title",
     i18n_description = "alerts_thresholds_config.custom_host_lua_script_description",
  },
}

-- #################################################################

return p2p
