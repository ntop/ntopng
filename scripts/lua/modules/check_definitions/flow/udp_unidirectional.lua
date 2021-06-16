--
-- (C) 2019-21 - ntop.org
--

-- Companion scripts (in addition to i18n)
-- scripts/callbacks/status_defs/status_udp_unidirectional.lua
-- scripts/callbacks/interface/flow/udp.lua

local checks = require("checks")
local alerts_api = require "alerts_api"
local alert_consts = require("alert_consts")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.network,

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_udp_unidirectional,

   default_value = {
   },

   gui = {
      i18n_title = "flow_checks_config.udp_unidirectional",
      i18n_description = "flow_checks_config.udp_unidirectional_description",
   }
}

-- #################################################################

return script
