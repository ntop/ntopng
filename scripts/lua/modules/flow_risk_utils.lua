--
-- (C) 2017-21 - ntop.org
--

local flow_risk_utils = {}

-- ##############################################

-- Keep in sync with ndpi_typedefs.h, table keys are risk ids as found in nDPI
flow_risk_utils.risks_by_id = {
   [0]  = "ndpi_no_risk",
   [1]  = "ndpi_url_possible_xss",
   [2]  = "ndpi_url_possible_sql_injection",
   [3]  = "ndpi_url_possible_rce_injection",
   [4]  = "ndpi_binary_application_transfer",
   [5]  = "ndpi_known_protocol_on_non_standard_port",
   [6]  = "ndpi_tls_selfsigned_certificate",
   [7]  = "ndpi_tls_obsolete_version",
   [8]  = "ndpi_tls_weak_cipher",
   [9]  = "ndpi_tls_certificate_expired",
   [10] = "ndpi_tls_certificate_mismatch",
   [11] = "ndpi_http_suspicious_user_agent",
   [12] = "ndpi_http_numeric_ip_host",
   [13] = "ndpi_http_suspicious_url",
   [14] = "ndpi_http_suspicious_header",
   [15] = "ndpi_tls_not_carrying_https",
   [16] = "ndpi_suspicious_dga_domain",
   [17] = "ndpi_malformed_packet",
   [18] = "ndpi_ssh_obsolete_client_version_or_cipher",
   [19] = "ndpi_ssh_obsolete_server_version_or_cipher",
   [20] = "ndpi_smb_insecure_version",
   [21] = "ndpi_tls_suspicious_esni_usage",
   [22] = "ndpi_unsafe_protocol",
   [23] = "ndpi_dns_suspicious_traffic",
   [24] = "ndpi_tls_missing_sni",
   [25] = "ndpi_http_invalid_content",
   [26] = "ndpi_risky_asn",
   [27] = "ndpi_risky_domain",
   [28] = "ndpi_malicious_ja3",
   [29] = "ndpi_malicious_sha1_certificate",
   [30] = "ndpi_desktop_or_file_sharing_session",
}

-- ##############################################

-- Same as flow_risk_utils.risks_by_id, just with keys swapped
flow_risk_utils.risks = {}
for risk_id, risk_name in pairs(flow_risk_utils.risks_by_id) do
   flow_risk_utils.risks[risk_name] = risk_id
end

-- ##############################################

-- @brief Returns an i18n-localized risk description given a risk_id as defined in nDPI
function flow_risk_utils.risk_id_2_i18n(risk_id)
   if risk_id and flow_risk_utils.risks_by_id[risk_id] then
      return i18n("flow_risk."..flow_risk_utils.risks_by_id[risk_id])
   end

   return risk_id
end

-- ##############################################

-- @brief Returns the list of risks with info including name and i18n description
function flow_risk_utils.get_risks_info()
   local risks_info = {}

   for risk_id, risk_name in pairs(flow_risk_utils.risks_by_id) do
      risks_info[risk_id] = {
         name = risk_name,
         label = flow_risk_utils.risk_id_2_i18n(risk_id),
      }
   end

   return risks_info
end

-- ##############################################

return flow_risk_utils
