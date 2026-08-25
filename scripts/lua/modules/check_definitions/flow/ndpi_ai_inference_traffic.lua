--
-- (C) 2019-26 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   category = checks.check_categories.security,

   alert_id = flow_alert_keys.flow_alert_ndpi_ai_inference_traffic,

   default_enabled = true,

   default_value = {
   },

   gui = {
      i18n_title = "flow_risk.ndpi_ai_inference_traffic",
      i18n_description = "flow_risk.ndpi_ai_inference_traffic_descr",
   }
}

-- #################################################################

return script
