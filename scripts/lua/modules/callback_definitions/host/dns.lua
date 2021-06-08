--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local dns = {
   -- Script category
   category = user_scripts.script_categories.network,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_dns_traffic,

   default_value = {
      operator = "gt",
   },

   gui = {
      i18n_title = "alerts_thresholds_config.dns_traffic",
      i18n_description = "alerts_thresholds_config.alert_dns_description",
      i18n_field_unit = user_scripts.field_units.bytes,
      input_builder = "threshold_cross",
      field_operator = "gt";
   },
}

-- #################################################################

return dns
