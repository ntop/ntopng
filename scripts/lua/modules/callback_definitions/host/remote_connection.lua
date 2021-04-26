--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local host_alert_keys = require "host_alert_keys"

local remote_connection = {
   -- Script category
   category = user_scripts.script_categories.network,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_remote_connection,

   default_value = {
      severity = alert_severities.notice,
   },
   
   gui = {
      i18n_title = "alerts_dashboard.remote_connection_title",
      i18n_description = "alerts_dashboard.remote_connection_description",
   }
}

-- #################################################################

return remote_connection
