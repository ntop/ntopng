--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatKPoNSPStatus(info)
   local res = i18n("alerts_dashboard.known_proto_on_non_std_port")

   if info then
      local app = info["proto.ndpi_app"] or info["proto.ndpi"]

      if app then
	 res = i18n("alerts_dashboard.known_proto_on_non_std_port_full", {app = app, port = info["srv.port"]})
      end
   end

   return res
end

-- #################################################################

-- scripts/lua/modules/alert_definitions/alert_known_proto_on_non_std_port.lua

return {
   -- scripts/lua/modules/flow_keys.lua
   status_key = status_keys.ntopng.status_known_proto_on_non_std_port,
   -- scripts/lua/modules/alert_keys.lua
   alert_type = alert_consts.alert_types.alert_known_proto_on_non_std_port,
   -- scripts/locales/en.lua
   i18n_title = "alerts_dashboard.known_proto_on_non_std_port",
   i18n_description = formatKPoNSPStatus
}
