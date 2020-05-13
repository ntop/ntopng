--
-- (C) 2017-20 - ntop.org
--

local flow_risk_utils = {}

-- ##############################################

-- Keep in sync with ndpi_typedefs.h
local id_2_i18n = {
   [0] = "ndpi_no_risk",
   [1] = "ndpi_url_possible_xss",
   [2] = "ndpi_url_possible_sql_injection",
   [3] = "ndpi_url_possible_rce_injection",
   [4] = "ndpi_binary_application_transfer",
   [5] = "ndpi_known_protocol_on_non_standard_port",
   [6] = "ndpi_tls_selfsigned_certificate",
   [7] = "ndpi_tls_obsolete_version",
   [8] = "ndpi_tls_weak_cipher",
}

-- ##############################################

-- @brief Returns an i18n-localized risk description given a risk_id as defined in nDPI
function flow_risk_utils.risk_id_2_i18n(risk_id)
   if risk_id and id_2_i18n[risk_id] then
      return i18n("flow_risk."..id_2_i18n[risk_id])
   end
end

-- ##############################################

return flow_risk_utils
