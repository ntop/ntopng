--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local host_ban = {
   -- Script category
   category = user_scripts.script_categories.security,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_host_ban,

   default_value = {
      operator = "gt",
      threshold = "1000",
   },

   gui = {
      i18n_title = "alerts_dashboard.host_ban_title",
      i18n_description = "alerts_dashboard.host_ban_description",
      i18n_field_unit = user_scripts.field_units.score,
      input_builder = "threshold_cross",
      field_operator = "gt";
   },
}

-- #################################################################

return host_ban
