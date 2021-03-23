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
   alerts_api.handlerPeerBehaviour(params, stats, nil, host_ip, nil --[[ as client --]], nil, "Contacts Behaviour")
end

-- #################################################################

return handler

