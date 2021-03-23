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
      -- Set flow status and trigger an alert when a suspicious file transfer is detected
   local anomaly     = stats["anomaly"]	
   local lower_bound = stats["lower_bound"]
   local upper_bound = stats["upper_bound"]
   local value       = stats["value"]
   local prediction  = stats["prediction"]

   if anomaly == true then
      local alert = alert_consts.alert_types.alert_unexpected_behaviour.new(
	 "Domain Visited", -- Type of unexpected behaviour
	 value,
	 prediction,
	 upper_bound,
	 lower_bound
      )

      alert:set_granularity(params.granularity)
      
      alert:set_severity(alert_severities.warning)
      
      alert:store(params.alert_entity)
   end
end

-- #################################################################

return handler

