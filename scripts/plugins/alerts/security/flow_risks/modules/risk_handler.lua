--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

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
   local alert = alert_consts.alert_types.alert_flow_risk.new(
      risk_id
   )

   alert:set_severity(alert_severities.warning)

   alert:trigger_status(cli_score or 0, srv_score or 0, flow_score or 0)
end

-- #################################################################

return handler

