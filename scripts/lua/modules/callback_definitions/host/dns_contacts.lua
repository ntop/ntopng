--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local dns_contacts = {
   -- Script category
   category = user_scripts.script_categories.security,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_dns_server_contacts,

   default_value = {
      severity = alert_severities.error,
   },

   gui = {
      i18n_title = "alerts_thresholds_config.dns_contacts_title",
      i18n_description = "alerts_thresholds_config.dns_contacts_description",
   }
}

-- #################################################################

return dns_contacts
