--
-- (C) 2019-26 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security,

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_ndpi_non_pqc_flow,

   default_enabled = true,

   default_value = {
   },

   gui = {
      i18n_title = "flow_risk.ndpi_non_pqc_flow",
      i18n_description = "flow_risk.ndpi_non_pqc_flow_descr",
   }
}

-- #################################################################

return script
