--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local countries_contacts = {
   -- Script category
   category = checks.check_categories.security,

   default_enabled = true,
   alert_id = host_alert_keys.host_alert_countries_contacts,

   default_value = {
      operator = "gt",
      threshold = 100,
   },

   gui = {
      i18n_title = "alerts_thresholds_config.countries_contacts_title",
      i18n_description = "alerts_thresholds_config.countries_contacts_description",
      i18n_field_unit = checks.field_units.contacts,
      input_builder = "threshold_cross",
      field_max = 65535,
      field_min = 1,
      field_operator = "gt";
   }
}

-- #################################################################

return countries_contacts
