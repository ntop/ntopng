--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

-- #################################################################

local handler = {}

-- #################################################################

-- @brief See risk_handler.lua
function handler.handle_behaviour(params, stats, host_ip)
   -- Client anomaly
   local anomaly_cli    = stats["as_client.anomaly"]	
   local lower_cli      = stats["as_client.lower_bound"]
   local upper_cli      = stats["as_client.upper_bound"]
   local value_cli      = stats["as_client.value"]
   local prediction_cli = stats["as_client.prediction"]
   -- Server
   local anomaly_srv    = stats["as_server.anomaly"]	
   local lower_srv      = stats["as_server.lower_bound"]
   local upper_srv      = stats["as_server.upper_bound"]
   local value_srv      = stats["as_server.value"]
   local prediction_srv = stats["as_server.prediction"]

   -- Client
   local alert_cli = alert_consts.alert_types.alert_unexpected_behaviour.new(
      "Active Flows as Client", -- Type of unexpected behaviour
      value_cli,
      prediction_cli,
      upper_bound_cli,
      lower_bound_cli
   )
   
   -- Server
   local alert_srv = alert_consts.alert_types.alert_unexpected_behaviour.new(
      "Active Flows as Server", -- Type of unexpected behaviour
      value_srv,
      prediction_srv,
      upper_bound_srv,
      lower_bound_cli
   )

   alert_cli:set_granularity(params.granularity)
   alert_srv:set_granularity(params.granularity)

   alert_cli:set_severity(alert_severities.warning)
   alert_srv:set_severity(alert_severities.warning)

   if anomaly_cli == true then
      alert_cli:trigger(params.alert_entity, nil, params.cur_alerts)
   else
      alert_cli:release(params.alert_entity, nil, params.cur_alerts)
   end

   if anomaly_srv == true then
      alert_srv:trigger(params.alert_entity, nil, params.cur_alerts)
   else
      alert_srv:release(params.alert_entity, nil, params.cur_alerts)
   end
end

-- #################################################################

return handler
