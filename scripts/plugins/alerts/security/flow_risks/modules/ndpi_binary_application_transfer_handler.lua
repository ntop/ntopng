--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")

-- #################################################################

local handler = {}

-- #################################################################

-- @brief See risk_handler.lua
function handler.handle_risk(flow_score, cli_score, srv_score)
   -- NDPI_BINARY_APPLICATION_TRANSFER
   -- scripts/lua/modules/alert_definitions/alert_suspicious_file_transfer.lua

   local http_info = flow.getHTTPInfo()
   local url = http_info["protos.http.last_url"] or ""

   -- Set flow status and trigger an alert when a suspicious file transfer is detected
   flow.triggerStatus(
      flow_consts.status_types.status_suspicious_file_transfer.create(
	 flow_consts.status_types.status_suspicious_file_transfer.alert_severity,
	 http_info
      ),
      flow_score or 0, -- flow_score
      cli_score or 0,  -- cli_score
      srv_score or 0   -- srv_score
   )
end

-- #################################################################

return handler

