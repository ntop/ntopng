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
function handler.handle_risk(risk_id, flow_score, cli_score, srv_score)
   -- ndpi_url_possible_xss
   -- Set flow status and trigger an alert when a possible xss is detected
   local alert = alert_consts.alert_types.alert_ndpi_dns_suspicious_traffic.new()

   alert:set_severity(alert_severities.warning)

   alert:trigger_status(cli_score or 0, srv_score or 0, flow_score or 0)
end

-- #################################################################

return handler
