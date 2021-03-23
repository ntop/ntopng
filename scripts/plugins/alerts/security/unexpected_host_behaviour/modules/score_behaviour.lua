--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

-- #################################################################

local handler = {}

-- #################################################################

local function handle_peer_behavior(params, stats, host_ip, as_client)
   if true then
      -- TODO: remove when done
      return
   end

   local       anomaly     = stats["anomaly"]
   local       lower_bound = stats["lower_bound"]
   local       upper_bound = stats["upper_bound"]
   local       value       = stats["value"]
   local       prediction  = stats["prediction"]

   -- Delta to compute the severity
   -- use as_client also to differentiate between client and server deltas
   local delta_num_threshold_crosses = alerts_api.network_delta_val(params.user_script.key.." "..tostring(as_client), params.granularity, num_threshold_crosses, true)

   local alert_unexpected_behaviour = alert_consts.alert_types.alert_unexpected_behaviour.new(
      "Score Behaviour as Client / Server", -- Type of unexpected behavior -- TODO: localize (use as_client)
      value,
      prediction,
      upper_bound,
      lower_bound
   )

   alert_unexpected_behaviour:set_severity(alert_severities.error)

   alert_unexpected_behaviour:set_granularity(params.granularity)

   -- Must specify the subtype to avoid clashes
   alert_unexpected_behaviour:set_subtype(tonumber(as_client))

   if delta_num_threshold_crosses > 5 then -- means that threshold has been exceeded 5 times across two consecutive calls
      -- Updating the severity to redis
      alert_unexpected_behaviour:trigger(params.alert_entity)
   else
      alert_unexpected_behaviour:release(params.alert_entity)
   end
end


-- #################################################################

-- @brief See risk_handler.lua
function handler.handle_behaviour(params, stats, host_ip)
   handle_peer_behavior(params, stats["as_client"], host_ip, true --[[ as client --]])
   handle_peer_behavior(params, stats["as_server"], host_ip, false --[[ as server --]])
end

-- #################################################################

return handler
