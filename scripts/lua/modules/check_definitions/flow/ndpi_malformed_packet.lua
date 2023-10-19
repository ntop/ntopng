--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security, 

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_ndpi_malformed_packet,

   default_enabled = true,

   default_value = {
   },


   gui = {
      i18n_title = "flow_risk.ndpi_malformed_packet",
      i18n_description = "flow_risk.ndpi_malformed_packet",
   }
}

-- #################################################################

return script
