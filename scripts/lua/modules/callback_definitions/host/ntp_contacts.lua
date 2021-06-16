--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local ntp_contacts = {
  -- Script category
  category = checks.check_categories.security,

  default_enabled = false,
  alert_id = host_alert_keys.host_alert_ntp_server_contacts,

  default_value = {
     operator = "gt",
     threshold = 5,
  },

  gui = {
    i18n_title = "alerts_thresholds_config.ntp_contacts_title",
    i18n_description = "alerts_thresholds_config.ntp_contacts_description",
    i18n_field_unit = checks.field_units.contacts,
    input_builder = "threshold_cross",
    field_max = 65535,
    field_min = 1,
    field_operator = "gt";
   }
}

-- #################################################################

return ntp_contacts
