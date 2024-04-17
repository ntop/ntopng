--
-- (C) 2019-24 - ntop.org
--

local checks = require("checks")
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
      i18n_title = "flow_checks_config.remote_to_local_insecure_flow_title",
      i18n_description = "flow_checks_config.remote_to_local_insecure_flow_description",
   }
}

-- #################################################################

return script
