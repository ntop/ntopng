--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
local alerts_api = require("alerts_api")

-- #################################################################

local handler = {}

-- #################################################################

-- @brief See risk_handler.lua
function handler.handle_behaviour(params, stats, host_ip)
   alerts_api.handlerPeerBehaviour(params, stats["as_client"], stats["tot_num_anomalies"], host_ip, "client" --[[ as client --]], nil, "Active Flows Behaviour as Client")
   alerts_api.handlerPeerBehaviour(params, stats["as_server"], stats["tot_num_anomalies"], host_ip, "server" --[[ as server --]], nil, "Active Flows Behaviour as Server")
end

-- #################################################################

return handler
