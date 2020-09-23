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

local function ndpi_binary_application_transfer_handler()
   -- NDPI_BINARY_APPLICATION_TRANSFER
   -- scripts/lua/modules/alert_definitions/alert_suspicious_file_transfer.lua

   local http_info = flow.getHTTPInfo()
   local url = http_info["protos.http.last_url"] or ""

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

-- #################################################################

local function ndpi_known_protocol_on_non_standard_port_handler()
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

-- #################################################################

local function default_handler()
   -- A generic handler for all flow risks
   local info = flow.getInfo()

   flow.triggerStatus(
      flow_consts.status_types.status_flow_risk.create(
	 flow_consts.status_types.status_flow_risk.alert_severity,
	 info
      ),
      50, -- flow_score
      50, -- cli_score
      50  -- srv_score
   )
end

-- #################################################################

local function no_action_handler()
   -- An handler which doesn't perform any action. Useful
   -- to be associated with risks already handled on other user scripts
end

-- #################################################################

-- A Lua table to map risks with a given handler
-- Risks are identified with ids as found in ndpi_typedefs.h
local risk2action = {
   [0]  = default_handler,                                     -- "ndpi_no_risk"
   [1]  = default_handler,                                     -- "ndpi_url_possible_xss"
   [2]  = default_handler,                                     -- "ndpi_url_possible_sql_injection"
   [3]  = default_handler,                                     -- "ndpi_url_possible_rce_injection"
   [4]  = ndpi_binary_application_transfer_handler,            -- "ndpi_binary_application_transfer"
   [5]  = ndpi_known_protocol_on_non_standard_port_handler,    -- "ndpi_known_protocol_on_non_standard_port"
   [6]  = no_action_handler,                                   -- handled in tls_certificate_selfsigned.lua
   [7]  = no_action_handler,                                   -- handled in tls_old_version.lua
   [8]  = no_action_handler,                                   -- handled in tls_unsafe_ciphers.lua
   [9]  = no_action_handler,                                   -- handled in tls_certificate_expired.lua
   [10] = no_action_handler,                                   -- handled in tls_certificate_mismatch.lua TODO: migrate to flow risk
   [11] = default_handler,                                     -- "ndpi_http_suspicious_user_agent"
   [12] = default_handler,                                     -- "ndpi_http_numeric_ip_host"
   [13] = default_handler,                                     -- "ndpi_http_suspicious_url"
   [14] = default_handler,                                     -- "ndpi_http_suspicious_header"
   [15] = default_handler,                                     -- "ndpi_tls_not_carrying_https"
   [16] = default_handler,                                     -- "ndpi_suspicious_dga_domain"
   [17] = default_handler,                                     -- "ndpi_malformed_packet"
   [18] = default_handler,                                     -- "ndpi_ssh_obsolete_client_version_or_cipher"
   [19] = default_handler,                                     -- "ndpi_ssh_obsolete_server_version_or_cipher"
   [20] = default_handler,                                     -- "ndpi_smb_insecure_version"
   [21] = default_handler,                                     -- "ndpi_tls_suspicious_esni_usage"
   [22] = default_handler,                                     -- "ndpi_unsafe_protocol"
   [23] = default_handler,                                     -- "ndpi_dns_suspicious_traffic"
   [24] = default_handler,                                     -- "ndpi_tls_missing_sni"
}

-- #################################################################

function script.hooks.protocolDetected(now)
   -- If the flow has any of the nDPI risks...
   if flow.hasRisk() then
      -- Perform per-risk actions, according to the risk2action table
      local all_risks = flow.getRiskInfo()

      for risk_str, risk_id in pairs(all_risks) do
	 if risk2action[risk_id] then
	    -- If the action is found in the table, use it
	    risk2action[risk_id]()
	 else
	    -- Use a default handler
	    default_handler()
	 end
      end
   end
end

-- #################################################################

return script
