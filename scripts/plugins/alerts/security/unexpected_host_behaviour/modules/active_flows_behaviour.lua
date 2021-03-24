--
-- (C) 2019-21 - ntop.org
--

require "lua_utils"
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
local alerts_api = require("alerts_api")

-- #################################################################

local handler = {}

-- #################################################################

-- @brief See risk_handler.lua
function handler.handle_behaviour(params, stats, host_ip)
   alerts_api.handlerPeerBehaviour(params, stats["as_client"], nil, host_ip, nil, alert_consts.alert_types.alert_active_flows_anomaly_client, "active_flows_behaviour_as_client") 
   alerts_api.handlerPeerBehaviour(params, stats["as_server"], nil, host_ip, nil, alert_consts.alert_types.alert_active_flows_anomaly_server, "active_flows_behaviour_as_server") 
end

-- #################################################################

return handler
