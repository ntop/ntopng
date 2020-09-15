--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local flow_consts = require("flow_consts")
local flow_risks = require("flow_risk_utils")

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security, 

   -- Priority
   prio = -20, -- Lower priority (executed after) than default 0 priority

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.flow_risk",
      i18n_description = "flow_callbacks_config.flow_risk_description",
   }
}

-- #################################################################

function script.hooks.protocolDetected(now)
   -- For value information see nDPI/src/include/ndpi_typedefs.h
   if flow.hasRisk(flow_risks.risks.ndpi_binary_application_transfer) then
      local http_info = flow.getHTTPInfo()
      local url      = http_info["protos.http.last_url"] or ""

      -- NDPI_BINARY_APPLICATION_TRANSFER
      -- scripts/lua/modules/alert_definitions/alert_suspicious_file_transfer.lua
      flow.triggerStatus(
	 flow_consts.status_types.status_suspicious_file_transfer.create(
	    flow_consts.status_types.status_suspicious_file_transfer.alert_severity,
	    http_info
	 ),
	 200, -- flow_score
	 200, -- cli_score
	 200  -- srv_score
      )
   end

   if flow.hasRisk(flow_risks.risks.ndpi_known_protocol_on_non_standard_port) then
      -- NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT
      -- scripts/lua/modules/alert_definitions/alert_known_proto_on_non_std_port.lua
      local info = flow.getInfo()

      flow.triggerStatus(
	 flow_consts.status_types.status_known_proto_on_non_std_port.create(
	    flow_consts.status_types.status_known_proto_on_non_std_port.alert_severity,
	    info
	 ),
	 100, -- flow_score
	 100, -- cli_score
	 100  -- srv_score
      )
   end
end

-- #################################################################

return script
