--
-- (C) 2019-21 - ntop.org
--

-- Companion scripts (in addition to i18n)
-- scripts/callbacks/status_defs/status_udp_unidirectional.lua
-- scripts/callbacks/interface/flow/udp.lua

local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.network,

   l4_proto = "udp",

   -- This script is only for alerts generation
   is_alert = true,

   default_value = {
      severity = alert_severities.notice,
   },

   gui = {
      i18n_title = "flow_callbacks_config.udp_unidirectional",
      i18n_description = "flow_callbacks_config.udp_unidirectional_description",
   }
}

-- #################################################################

return script
