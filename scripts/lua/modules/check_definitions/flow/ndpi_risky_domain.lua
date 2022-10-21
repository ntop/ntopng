--
-- (C) 2019-22 - ntop.org
--


local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.network,

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_ndpi_risky_domain,

   default_value = {
   },

   gui = {
      i18n_title = "flow_checks_config.risky_domain",
      i18n_description = "flow_checks_config.risky_domain_description",
   }
}

-- #################################################################

return script
