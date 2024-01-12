--
-- (C) 2019-24 - ntop.org
--


local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security,

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_ndpi_http_obsolete_server,

   default_value = {
   },

   gui = {
      i18n_title = "flow_checks_config.http_obsolete_server",
      i18n_description = "flow_checks_config.http_obsolete_server_description",
   }
}

-- #################################################################

return script
