--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local flow_consts = require("flow_consts")
local alerts_api = require "alerts_api"
local alert_consts = require("alert_consts")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security, 

   default_enabled = true,

   alert_id = flow_alert_keys.flow_alert_remote_to_local_insecure_proto,

   default_value = {
   },

   gui = {
      i18n_title = "flow_checks_config.remote_to_local_insecure_proto_title",
      i18n_description = "flow_checks_config.remote_to_local_insecure_proto_description",
   }
}

-- #################################################################

return script
