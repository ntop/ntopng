--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"
local alert_consts = require("alert_consts")

-- #################################################################

local smtp_contacts = {
  -- Script category
  category = checks.check_categories.network,
  severity = alert_consts.get_printable_severities().notice,

  default_enabled = false,
  alert_id = host_alert_keys.host_alert_smtp_server_contacts,

  default_value = {
     operator = "gt",
     threshold = 5,
  },

  gui = {
    i18n_title = "alerts_thresholds_config.smtp_contacts_title",
    i18n_description = "alerts_thresholds_config.smtp_contacts_description",
    i18n_field_unit = checks.field_units.contacts,
    input_builder = "threshold_cross",
    field_max = 65535,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

return smtp_contacts
