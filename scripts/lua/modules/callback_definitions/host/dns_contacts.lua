--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"

-- #################################################################

local dns_contacts = {
   -- Script category
   category = user_scripts.script_categories.security,

   default_enabled = false,

   default_value = {
      operator = "gt",
      threshold = 5,
      severity = alert_severities.error,
   },

   gui = {
      i18n_title = "alerts_thresholds_config.dns_contacts_title",
      i18n_description = "alerts_thresholds_config.dns_contacts_description",
      i18n_field_unit = user_scripts.field_units.contacts,
      input_builder = "threshold_cross",
      field_max = 65535,
      field_min = 1,
      field_operator = "gt";
   }
}

-- #################################################################

return dns_contacts
