--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local alert_consts = require("alert_consts")
local host_alert_keys = require "host_alert_keys"

local domain_names_contacts = {
   -- Script category
   category = checks.check_categories.network,
   severity = alert_consts.get_printable_severities().notice,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_domain_names_contacts,

   -- The default threshold value. The format is specific of the
   -- "threshold_cross" input builder
   default_value = {
      operator = "gt",
      threshold = 250,
   },

   -- Allow user script configuration from the GUI
   gui = {
      i18n_title = "alerts_thresholds_config.domain_names_contacts_title",
      i18n_description = "alerts_thresholds_config.domain_names_contacts_description",

      -- The input builder to use to draw the gui
      input_builder = "threshold_cross",
      
      -- Specific parameters of this input builder
      i18n_field_unit = checks.field_units.contacts,

      -- max allowed threshold value
      field_max = 65535,
      -- min allowed threshold value
      field_min = 1,
      -- threshold check operator. "gt" for ">", "lt" for "<"
      field_operator = "gt";
   }
}

-- #################################################################

return domain_names_contacts
