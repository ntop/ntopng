--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require "user_scripts"
local flow_risks = require "flow_risk_utils"
local plugins_utils = require "plugins_utils"
local alerts_api = require "alerts_api"

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security,

   -- Priority
   prio = -20, -- Lower priority (executed after) than default 0 priority

   -- For a full list check "available_subdir.flow.available_fields" in user_scripts.lua
   filter = {
      default_fields = { "srv_addr", "l7_proto", "flow_risk_bitmap" }
   },

   -- NOTE: hooks defined below
   hooks = {},

   is_alert = true,
   
   gui = {
      i18n_title = "flow_callbacks_config.flow_risk",
      i18n_description = "flow_callbacks_config.flow_risk_description",
   },

   filter = {
      default_filters = {},
      default_fields = {
	 "srv_addr",
	 "flow_risk_bitmap",
      },
   },
}

-- #################################################################

local excluded_risks = {
   [6]  = i18n("flow_risk.ndpi_tls_selfsigned_certificate"), -- handled in tls_certificate_selfsigned.lua
   [7]  = i18n("flow_risk.ndpi_tls_obsolete_version"),       -- handled in tls_old_protocol_version.lua
   [8]  = i18n("flow_risk.ndpi_tls_weak_cipher"),            -- handled in tls_certificate_expired.lua
   [9]  = i18n("flow_risk.ndpi_tls_certificate_expired"),    -- handled in tls_certificate_expired.lua
   [10] = i18n("flow_risk.ndpi_tls_certificate_mismatch"),   -- handled in tls_certificate_mismatch.lua TODO: migrate to flow risk
}

-- #################################################################

-- Default scores to use for flow risks
local DEFAULT_SCORES = {
   50 --[[ flow score   --]],
   50 --[[ client score --]],
   50 --[[ server score --]]}

-- #################################################################

-- A Lua table to map flow-, client- and server-score to any given flow risks.
-- Risks are identified with ids as found in ndpi_typedefs.h
local risk2scores = {
   -- Format is:
   -- [<flow risk id>] = {<flow_score>, <client_score>, <server_score>}
   --
   [0]  = DEFAULT_SCORES,             -- "ndpi_no_risk"
   [1]  = DEFAULT_SCORES,             -- "ndpi_url_possible_xss"
   [2]  = DEFAULT_SCORES,             -- "ndpi_url_possible_sql_injection"
   [3]  = DEFAULT_SCORES,             -- "ndpi_url_possible_rce_injection"
   [4]  = {200, 200, 200},            -- "ndpi_binary_application_transfer"
   [5]  = {100, 100, 100},            -- "ndpi_known_protocol_on_non_standard_port"
   [11] = DEFAULT_SCORES,             -- "ndpi_http_suspicious_user_agent"
   [12] = DEFAULT_SCORES,             -- "ndpi_http_numeric_ip_host"
   [13] = DEFAULT_SCORES,             -- "ndpi_http_suspicious_url"
   [14] = DEFAULT_SCORES,             -- "ndpi_http_suspicious_header"
   [15] = DEFAULT_SCORES,             -- "ndpi_tls_not_carrying_https"
   [16] = DEFAULT_SCORES,             -- "ndpi_suspicious_dga_domain"
   [17] = DEFAULT_SCORES,             -- "ndpi_malformed_packet"
   [18] = DEFAULT_SCORES,             -- "ndpi_ssh_obsolete_client_version_or_cipher"
   [19] = DEFAULT_SCORES,             -- "ndpi_ssh_obsolete_server_version_or_cipher"
   [20] = DEFAULT_SCORES,             -- "ndpi_smb_insecure_version"
   [21] = DEFAULT_SCORES,             -- "ndpi_tls_suspicious_esni_usage"
   [22] = DEFAULT_SCORES,             -- "ndpi_unsafe_protocol"
   [23] = DEFAULT_SCORES,             -- "ndpi_dns_suspicious_traffic"
   [24] = DEFAULT_SCORES,             -- "ndpi_tls_missing_sni"
}

-- #################################################################

-- For risks that have dedicated handler (e.g., to trigger a special flow status and not the generic 'flow-risk' status)
-- a dedicated handler can be indicated. Handlers are lua modules placed under flow_risks/modules/ implementing function
--
--   function handler.handle_risk(flow_score, cli_score, srv_score)
-- 
local handlers = {
   [1]  = "ndpi_url_possible_xss_handler",
   [2]  = "ndpi_url_possible_sql_injection_handler",
   [3]  = "ndpi_url_possible_rce_injection_handler",
   [4]  = "ndpi_binary_application_transfer_handler",            -- "ndpi_binary_application_transfer"
   [5]  = "ndpi_known_protocol_on_non_standard_port_handler",    -- "ndpi_known_protocol_on_non_standard_port"
   [11] = "ndpi_http_suspicious_user_agent_handler",
   [12] = "ndpi_http_numeric_ip_host_handler",
   [13] = "ndpi_http_suspicious_url_handler",
   [14] = "ndpi_http_suspicious_header_handler",
   [15] = "ndpi_tls_not_carrying_https_handler",
   [16] = "ndpi_suspicious_dga_domain_handler",
   [17] = "ndpi_malformed_packet_handler",
   [18] = "ndpi_ssh_obsolete_handler",
   [19] = "ndpi_ssh_obsolete_handler",
   [20] = "ndpi_smb_insecure_version_handler",
   [21] = "ndpi_tls_suspicious_esni_usage_handler",
   [22] = "ndpi_unsafe_protocol_handler",
   [23] = "ndpi_dns_suspicious_traffic_handler",
   [24] = "ndpi_tls_missing_sni_handler",
   
}

-- #################################################################

function script.setup()
   -- Reset enabled risks. They will be lazily re-initialized inside protocolDetected hook below

   return true -- OK
end

-- #################################################################

function script.hooks.protocolDetected(now, conf)
   -- If the flow has any of the nDPI risks...
   if flow.hasRisk() then
      -- Iterate all the currently detected flow risks
      local all_risks = flow.getRiskInfo()

      for risk_str, risk_id in pairsByValues(all_risks, asc) do
	 if excluded_risks[risk_id] then
	    goto continue
	 end

	 -- If the risk is not among those enabled, just skip it
	 local handler
	 if handlers[risk_id] then
	    -- There's a dedicated handler implemented for this risk_id. Let's load it as a module
	    handler = plugins_utils.loadModule("flow_risks",  handlers[risk_id])
	 else
	    -- No dedicated handler found, let's use a default risk handler
	    handler = plugins_utils.loadModule("flow_risks", "risk_handler")
	 end

	 if handler and handler.handle_risk then
	    -- Handler expect three params, namely flow-, client- and server-scores
	    handler.handle_risk(risk_id, table.unpack(risk2scores[risk_id] or DEFAULT_SCORES))
	 end

	 ::continue::
      end
   end
end

-- #################################################################

return script
