--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local host_alert_keys = require "host_alert_keys"
local alert_consts = require("alert_consts")

-- #################################################################

local dangerous_host = {
   -- Script category
   category = checks.check_categories.ids_ips,
   severity = alert_consts.get_printable_severities().error,

   default_enabled = false,
   alert_id = host_alert_keys.host_alert_dangerous_host,

   default_value = {
      operator = "gt",
      threshold = "1000",
   },

   gui = {
      i18n_title = "alerts_dashboard.dangerous_host_title",
      i18n_description = "alerts_dashboard.dangerous_host_description",
      i18n_field_unit = checks.field_units.score,
      input_builder = "threshold_cross",
      field_operator = "gt";
   },
}

-- #################################################################

return dangerous_host
