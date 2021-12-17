--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security, 

   default_enabled = true,

   alert_id = flow_alert_keys.flow_alert_broadcast_non_udp_traffic,

   gui = {
      i18n_title = "flow_checks_config.broadcast_non_udp_traffic_title",
      i18n_description = "flow_checks_config.broadcast_non_udp_traffic_description",
   }
}

-- #################################################################

return script
