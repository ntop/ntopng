--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security, 

   -- This script is only for alerts generation
   is_alert = true,

   default_enabled = true,

   default_value = {
      severity = alert_severities.error,
   },


   gui = {
      i18n_title = "flow_risk.ndpi_ssh_obsolete_server_version_or_cipher",
      i18n_description = "flow_risk.ndpi_ssh_obsolete_server_version_or_cipher",
   }
}

-- #################################################################

return script
