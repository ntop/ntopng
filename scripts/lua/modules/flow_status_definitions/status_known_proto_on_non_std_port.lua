--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

-- scripts/lua/modules/alert_definitions/alert_known_proto_on_non_std_port.lua

return {
   -- scripts/lua/modules/flow_keys.lua
   status_key = status_keys.ntopng.status_known_proto_on_non_std_port,
   alert_severity = alert_consts.alert_severities.warning,
   -- scripts/lua/modules/alert_keys.lua
   alert_type = alert_consts.alert_types.alert_known_proto_on_non_std_port,
   -- scripts/locales/en.lua
   i18n_title = "flow_details.known_proto_on_non_std_port"
}
