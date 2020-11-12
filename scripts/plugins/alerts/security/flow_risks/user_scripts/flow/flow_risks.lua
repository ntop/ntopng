--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require "user_scripts"
local flow_consts = require "flow_consts"
local flow_risks = require "flow_risk_utils"
local plugins_utils = require "plugins_utils"
local alerts_api = require "alerts_api"

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
      input_builder = "multi_select",
      i8n_multiselect_label = i18n("flow_callbacks_config.flow_risk_list"),

      groups = {
	 {
	    elements = {
	       { 1, i18n("flow_risk.ndpi_url_possible_xss") },
	       { 2, i18n("flow_risk.ndpi_url_possible_sql_injection") },
	       { 3, i18n("flow_risk.ndpi_url_possible_rce_injection") },
	       { 4, i18n("flow_risk.ndpi_binary_application_transfer") },
	       { 5, i18n("flow_risk.ndpi_known_protocol_on_non_standard_port") },
	       -- { 6, i18n("flow_risk.ndpi_tls_selfsigned_certificate") }, -- handled in tls_certificate_selfsigned.lua
	       -- { 7, i18n("flow_risk.ndpi_tls_obsolete_version") },       -- handled in tls_old_version.lua
	       -- { 8, i18n("flow_risk.ndpi_tls_weak_cipher") },            -- handled in tls_certificate_expired.lua
	       -- { 9, i18n("flow_risk.ndpi_tls_certificate_expired") },    -- handled in tls_certificate_expired.lua 
	       -- { 10, i18n("flow_risk.ndpi_tls_certificate_mismatch") },  -- handled in tls_certificate_mismatch.lua TODO: migrate to flow risk
	       { 11, i18n("flow_risk.ndpi_http_suspicious_user_agent") },
	       { 12, i18n("flow_risk.ndpi_http_numeric_ip_host") },
	       { 13, i18n("flow_risk.ndpi_http_suspicious_url") },
	       { 14, i18n("flow_risk.ndpi_http_suspicious_header") },
	       { 15, i18n("flow_risk.ndpi_tls_not_carrying_https") },
	       { 16, i18n("flow_risk.ndpi_suspicious_dga_domain") },
	       { 17, i18n("flow_risk.ndpi_malformed_packet") },
	       { 18, i18n("flow_risk.ndpi_ssh_obsolete_client_version_or_cipher") },
	       { 19, i18n("flow_risk.ndpi_ssh_obsolete_server_version_or_cipher") },
	       { 20, i18n("flow_risk.ndpi_smb_insecure_version") },
	       { 21, i18n("flow_risk.ndpi_tls_suspicious_esni_usage") },
	       { 22, i18n("flow_risk.ndpi_unsafe_protocol") },
	       { 23, i18n("flow_risk.ndpi_dns_suspicious_traffic") },
	       { 24, i18n("flow_risk.ndpi_tls_missing_sni") },   
	    }
	 }
      }
   },

   default_value = {
      items = {
	 1,2,3,4,5,
	 -- 6,7,8,9,10,
	 11,12,13,14,15,16,17,18,19,20,
	 21,22,23,24
      },
   },

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
   [4]  = "ndpi_binary_application_transfer_handler",            -- "ndpi_binary_application_transfer"
   [5]  = "ndpi_known_protocol_on_non_standard_port_handler",    -- "ndpi_known_protocol_on_non_standard_port"
}

-- #################################################################

-- Indicate risks that are enabled (i.e., configured to generate alerts from the UI)
local enabled_risks

-- #################################################################

function script.setup()
   -- Reset enabled risks. They will be lazily re-initialized inside protocolDetected hook below
   enabled_risks = nil

   return true -- OK
end

-- #################################################################

function script.hooks.protocolDetected(now, conf)
   -- If the flow has any of the nDPI risks...
   if flow.hasRisk() then
      -- Lazily initialize enabled_risks, if not already initialized
      if not enabled_risks then
	 enabled_risks = {}

	 if conf and conf.items then
	    -- Iterate configuration items, i.e., enabled risks, and
	    -- add their ids to the enabled_risks table
	    for _, risk_id in pairs(conf.items) do
	       -- Risk ids arrive as strings inside items, so the tonumber conversion is needed
	       enabled_risks[tonumber(risk_id)] = true
	    end
	 end
      end

      -- Iterate all the currently detected flow risks
      local all_risks = flow.getRiskInfo()

      for risk_str, risk_id in pairs(all_risks) do
	 -- If the risk is not among those enabled, just skip it
	 if not enabled_risks[risk_id] then
	    goto continue
	 end

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
