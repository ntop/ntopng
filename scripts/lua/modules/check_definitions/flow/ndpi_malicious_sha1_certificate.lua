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
   alert_id = flow_alert_keys.flow_alert_ndpi_malicious_sha1_certificate,

   default_value = {
   },

   gui = {
      i18n_title = "flow_checks_config.malicious_sha1_certificate",
      i18n_description = "flow_checks_config.malicious_sha1_certificate_description",
   }
}

-- #################################################################

return script
