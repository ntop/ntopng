--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")

-- #################################################################

local handler = {}

-- #################################################################

-- @brief See risk_handler.lua
function handler.handle_risk(risk_id, flow_score, cli_score, srv_score)
   -- NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT

   -- Set the flow status and trigger an alert when a known protocol is found to use a non-standard port
   flow.triggerStatus(
      flow_consts.status_types.status_known_proto_on_non_std_port.create(
	 flow_consts.status_types.status_known_proto_on_non_std_port.alert_severity,
	 flow.getInfo()
      ),
      flow_score or 0, -- flow_score
      cli_score or 0,  -- cli_score
      srv_score or 0   -- srv_score
   )
end

-- #################################################################

return handler

