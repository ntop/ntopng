--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local host_ban = {
   -- Script category
   category = user_scripts.script_categories.security,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_host_ban,

   default_value = {
      severity = alert_severities.error,
   },

   gui = {
      i18n_title = "alerts_dashboard.host_ban_title",
      i18n_description = "alerts_dashboard.host_ban_description",
   },
}

-- #################################################################

return host_ban
