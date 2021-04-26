--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security, 

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_ndpi_unsafe_protocol,

   default_enabled = true,

   default_value = {
      severity = alert_severities.error,
   },


   gui = {
      i18n_title = "flow_risk.ndpi_unsafe_protocol",
      i18n_description = "flow_risk.ndpi_unsafe_protocol",
   }
}

-- #################################################################

return script
