--
-- (C) 2019-21 - ntop.org
--

require "lua_utils"
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
local alert_utils = require("alert_utils")

-- #################################################################

local handler = {}

-- #################################################################

-- @brief See risk_handler.lua
function handler.handle_behaviour(params, stats, host_ip)
   alerts_api.handlerPeerBehaviour(params, stats["as_client"], stats["tot_num_anomalies"], host_ip, 10, alert_consts.alert_types.alert_score_anomaly_client, "score_behaviour_as_client")
   alerts_api.handlerPeerBehaviour(params, stats["as_server"], stats["tot_num_anomalies"], host_ip, 10, alert_consts.alert_types.alert_score_anomaly_server, "score_behaviour_as_server")
end

-- #################################################################

return handler
