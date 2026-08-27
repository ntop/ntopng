--
-- (C) 2019-26 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.network,

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_ndpi_minor_issues,

   default_value = {
   },

   gui = {
      i18n_title = "flow_risk.ndpi_minor_issues",
      i18n_description = "flow_risk.ndpi_minor_issues_descr",
   }
}

-- #################################################################

return script
