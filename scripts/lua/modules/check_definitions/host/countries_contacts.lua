--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"
local alert_consts = require("alert_consts")

-- #################################################################

local countries_contacts = {
   -- Script category
   category = checks.check_categories.security,
   severity = alert_consts.get_printable_severities().notice,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_countries_contacts,

   default_value = {
      operator = "gt",
      threshold = 100,
   },

   gui = {
      i18n_title = "alerts_thresholds_config.countries_contacts_title",
      i18n_description = "alerts_thresholds_config.countries_contacts_description",
      input_builder = "threshold_cross",
      i18n_field_unit = checks.field_units.contacts,
      field_max = 255,
      field_min = 1,
      field_operator = "gt";
   }
}

-- #################################################################

return countries_contacts
