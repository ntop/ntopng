--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security, 

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_known_proto_on_non_std_port,

   default_enabled = true,

   default_value = {
   },


   gui = {
      i18n_title = "flow_risk.ndpi_known_protocol_on_non_standard_port",
      i18n_description = "flow_risk.ndpi_known_protocol_on_non_standard_port",
   }
}

-- #################################################################

return script
