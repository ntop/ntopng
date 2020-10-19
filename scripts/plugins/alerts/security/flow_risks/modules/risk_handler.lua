--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")

-- #################################################################

-- Default risk handler for all flow-risks that don't have
-- a specific handler coded
local handler = {}

-- #################################################################

-- @brief Called by flow_risks.lua when a risk for the flow is detected.
--       flow_risks.lua also passes flow-, client- and server-score as parameters
-- @param risk_id Integer nDPI flow risk identifier
-- @param flow_score   An integer score that will be added to the total flow score
-- @param cli_score An integer score that will be added to the client score
-- @param srv_score An integer score that will be added to the server score
function handler.handle_risk(risk_id, flow_score, cli_score, srv_score)
   -- Set a flow status for the generic flow_risk. This will also
   -- cause an alert to be generated.
   flow.triggerStatus(
      flow_consts.status_types.status_flow_risk.create(
	 flow_consts.status_types.status_flow_risk.alert_severity,
	 risk_id
      ),
      flow_score or 0, -- flow_score
      cli_score or 0,  -- cli_score
      srv_score or 0   -- srv_score
   )
end

-- #################################################################

return handler

