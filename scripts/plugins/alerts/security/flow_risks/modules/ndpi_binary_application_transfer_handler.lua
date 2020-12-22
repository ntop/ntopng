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
   -- NDPI_BINARY_APPLICATION_TRANSFER
   -- scripts/lua/modules/alert_definitions/alert_suspicious_file_transfer.lua

   local http_info = flow.getHTTPInfo()
   local url = http_info["protos.http.last_url"] or ""

   -- Set flow status and trigger an alert when a suspicious file transfer is detected
   local suspicious_file_transfer_type = flow_consts.status_types.status_suspicious_file_transfer.create(
      http_info
   )
   
   alerts_api.trigger_status(suspicious_file_transfer_type, alert_severities.error, cli_score or 0, srv_score or 0, flow_score or 0)
   
end

-- #################################################################

return handler

