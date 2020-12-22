--
-- (C) 2019-20 - ntop.org
--

local alerts_api = require "alerts_api"
local flow_consts = require("flow_consts")
local alert_severities = require "alert_severities"

-- #################################################################

local handler = {}

-- #################################################################

-- @brief See risk_handler.lua
function handler.handle_risk(risk_id, flow_score, cli_score, srv_score)
   -- NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT

   -- Set the flow status and trigger an alert when a known protocol is found to use a non-standard port
   local known_proto_on_non_std_port_type = flow_consts.status_types.status_known_proto_on_non_std_port.create(
      flow.getInfo()
   )
   
   alerts_api.trigger_status(known_proto_on_non_std_port_type, alert_severities.info, cli_score or 0, srv_score or 0, flow_score or 0)

end

-- #################################################################

return handler

