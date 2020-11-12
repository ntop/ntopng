--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"
local flow_risk_utils = require "flow_risk_utils"
local alert_consts = require("alert_consts")

-- #################################################################

local function formatFlowRisk(info)
   -- No need to do special formatting of flow risk here, risks are already formatted
   -- inside the flow details page
   local res = i18n("alerts_dashboard.flow_risk")

   if info.risk_id then
      res = flow_risk_utils.risk_id_2_i18n(info.risk_id)
   end

   return res
end

-- #################################################################

-- scripts/lua/modules/alert_definitions/alert_known_proto_on_non_std_port.lua

return {
   -- scripts/lua/modules/flow_keys.lua
   status_key = status_keys.ntopng.status_flow_risk,
   -- scripts/lua/modules/alert_keys.lua
   alert_type = alert_consts.alert_types.alert_flow_risk,
   -- scripts/locales/en.lua
   i18n_title = "alerts_dashboard.flow_risk",
   i18n_description = formatFlowRisk
}
