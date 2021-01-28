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
function handler.handle_risk(conf, risk_id, flow_score, cli_score, srv_score)
   -- NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT

   -- Set the flow status and trigger an alert when a known protocol is found to use a non-standard port  
   local alert = alert_consts.alert_types.alert_known_proto_on_non_std_port.new(
      flow.getInfo()
   )

   alert:set_severity(conf.severity)

   alert:trigger_status(cli_score or 0, srv_score or 0, flow_score or 0)

end

-- #################################################################

return handler

