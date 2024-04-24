--
-- (C) 2019-24 - ntop.org
--

local checks = require("checks")
local alert_consts = require "alert_consts"
local alerts_api = require "alerts_api"
local flow_alert_keys = require "flow_alert_keys"


-- #################################################################

-- NOTE: this module is always enabled
local script = {
   -- Script category
   category = checks.check_categories.security,

   -- This module is disabled by default
   default_enabled = false,

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_tcp_flow_reset,

   default_value = {
   },
   
   gui = {
      i18n_title = "flow_checks_config.flow_reset_title",
      i18n_description = "flow_checks_config.flow_reset_description",
   }
}

return script