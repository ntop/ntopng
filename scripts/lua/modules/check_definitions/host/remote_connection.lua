--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

local remote_connection = {
   -- Script category
   category = checks.check_categories.network,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_remote_connection,

   default_value = {
   },
   
   gui = {
      i18n_title = "alerts_dashboard.remote_connection_title",
      i18n_description = "alerts_dashboard.remote_connection_description",
   }
}

-- #################################################################

return remote_connection
