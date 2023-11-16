--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.network, 

   default_enabled = true,

   alert_id = flow_alert_keys.flow_alert_connection_failed,

   default_value = {
   },

   gui = {
      i18n_title = "flow_checks_config.connection_failed_title",
      i18n_description = "flow_checks_config.connection_failed_description",
   }
}

-- #################################################################

return script
