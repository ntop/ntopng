/*
 *
 * (C) 2013-22 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* **************************************************** */

/*
 * Note about handled/defined/undefined nDPI Risks:
 *
 * - Flow risks which are handled through dedicated Checks are listed here, assigned
 *   to an alert type defined in FlowAlertTypeEnum, and the check is explicitly 
 *   registered in FlowChecksLoader::registerChecks
 * - Flow risks which are defined below and assigned to an alert type defined in 
 *   FlowAlertTypeEnum, but with no dedicated Check, are handled by FlowRiskGeneric
 *   automatically
 * - Other flow risks (not listed below or with flow_alert_normal as alert type) are
 *   not handled and they do not trigger an alert (they are just reported in the
 *   live flow information, without contributing to the score for instance)
 */

static const FlowAlertTypeExtended risk_enum_to_alert_type[NDPI_MAX_RISK] {
  /* NDPI_NO_RISK */
  { { flow_alert_normal, alert_category_other }, "ndpi_no_risk" },

  /* NDPI_URL_POSSIBLE_XSS */
  { { flow_alert_ndpi_url_possible_xss, alert_category_security }, "ndpi_url_possible_xss" },

  /* NDPI_URL_POSSIBLE_SQL_INJECTION */
  { { flow_alert_ndpi_url_possible_sql_injection, alert_category_security }, "ndpi_url_possible_sql_injection" },

  /* NDPI_URL_POSSIBLE_RCE_INJECTION */
  { { flow_alert_ndpi_url_possible_rce_injection, alert_category_security }, "ndpi_url_possible_rce_injection" },

  /* NDPI_BINARY_APPLICATION_TRANSFER */
  { { flow_alert_ndpi_binary_application_transfer, alert_category_security }, "binary_application_transfer" },

  /* NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT */
  { { flow_alert_ndpi_known_proto_on_non_std_port, alert_category_security }, "known_proto_on_non_std_port" },

  /* NDPI_TLS_SELFSIGNED_CERTIFICATE */
  { { flow_alert_ndpi_tls_certificate_selfsigned, alert_category_security }, "tls_certificate_selfsigned" },

  /* NDPI_TLS_OBSOLETE_VERSION */
  { { flow_alert_ndpi_tls_old_protocol_version, alert_category_security }, "tls_old_protocol_version" },

  /* NDPI_TLS_WEAK_CIPHER */
  { { flow_alert_ndpi_tls_unsafe_ciphers, alert_category_security }, "tls_unsafe_ciphers" },

  /* NDPI_TLS_CERTIFICATE_EXPIRED */
  { { flow_alert_ndpi_tls_certificate_expired,  alert_category_security }, "tls_certificate_expired" },

  /* NDPI_TLS_CERTIFICATE_MISMATCH */
  { { flow_alert_ndpi_tls_certificate_mismatch, alert_category_security }, "tls_certificate_mismatch" },

  /* NDPI_HTTP_SUSPICIOUS_USER_AGENT */
  { { flow_alert_ndpi_http_suspicious_user_agent, alert_category_security }, "ndpi_http_suspicious_user_agent" },

  /* NDPI_HTTP_NUMERIC_IP_HOST */
  { { flow_alert_ndpi_http_numeric_ip_host, alert_category_security }, "ndpi_http_numeric_ip_host" },

  /* NDPI_HTTP_SUSPICIOUS_URL */
  { { flow_alert_ndpi_http_suspicious_url, alert_category_security }, "ndpi_http_suspicious_url" },

  /* NDPI_HTTP_SUSPICIOUS_HEADER */
  { { flow_alert_ndpi_http_suspicious_header, alert_category_security }, "ndpi_http_suspicious_header" },

  /* NDPI_TLS_NOT_CARRYING_HTTPS */
  { { flow_alert_ndpi_tls_not_carrying_https, alert_category_security }, "ndpi_tls_not_carrying_https" },

  /* NDPI_SUSPICIOUS_DGA_DOMAIN */
  { { flow_alert_ndpi_suspicious_dga_domain, alert_category_security }, "ndpi_suspicious_dga_domain" },

  /* NDPI_MALFORMED_PACKET */
  { { flow_alert_ndpi_malformed_packet, alert_category_security }, "ndpi_malformed_packet" },

  /* NDPI_SSH_OBSOLETE_CLIENT_VERSION_OR_CIPHER */
  { { flow_alert_ndpi_ssh_obsolete_client,  alert_category_security }, "ndpi_ssh_obsolete_client" },

  /* NDPI_SSH_OBSOLETE_SERVER_VERSION_OR_CIPHER */
  { { flow_alert_ndpi_ssh_obsolete_server, alert_category_security }, "ndpi_ssh_obsolete_server" },

  /* NDPI_SMB_INSECURE_VERSION */
  { { flow_alert_ndpi_smb_insecure_version, alert_category_security }, "ndpi_smb_insecure_version" },

  /* NDPI_TLS_SUSPICIOUS_ESNI_USAGE */
  { { flow_alert_ndpi_tls_suspicious_esni_usage, alert_category_security }, "ndpi_tls_suspicious_esni_usage" },

  /* NDPI_UNSAFE_PROTOCOL */
  { { flow_alert_ndpi_unsafe_protocol, alert_category_security }, "ndpi_unsafe_protocol" },

  /* NDPI_DNS_SUSPICIOUS_TRAFFIC */
  { { flow_alert_ndpi_dns_suspicious_traffic, alert_category_security }, "ndpi_dns_suspicious_traffic" },

  /* NDPI_TLS_MISSING_SNI */
  { { flow_alert_ndpi_tls_missing_sni, alert_category_security }, "ndpi_tls_missing_sni" },

  /* NDPI_HTTP_SUSPICIOUS_CONTENT */
  { { flow_alert_ndpi_http_suspicious_content, alert_category_security }, "ndpi_http_suspicious_content" },

  /* NDPI_RISKY_ASN */
  { { flow_alert_ndpi_risky_asn, alert_category_security }, "ndpi_risky_asn" },

  /* NDPI_RISKY_DOMAIN */
  { { flow_alert_ndpi_risky_domain, alert_category_security }, "ndpi_risky_domain" },

  /* NDPI_MALICIOUS_JA3 */
  { { flow_alert_ndpi_malicious_ja3, alert_category_security }, "ndpi_malicious_ja3" },

  /* NDPI_MALICIOUS_SHA1_CERTIFICATE */
  { { flow_alert_ndpi_malicious_sha1_certificate, alert_category_security }, "ndpi_malicious_sha1_certificate" },

  /* NDPI_DESKTOP_OR_FILE_SHARING_SESSION */
  { { flow_alert_ndpi_desktop_or_file_sharing_session, alert_category_security }, "ndpi_desktop_or_file_sharing_session" },

  /* NDPI_TLS_UNCOMMON_ALPN */
  { { flow_alert_ndpi_tls_uncommon_alpn, alert_category_other }, "ndpi_tls_uncommon_alpn" },

  /* NDPI_TLS_CERT_VALIDITY_TOO_LONG */
  { { flow_alert_ndpi_tls_cert_validity_too_long, alert_category_security }, "ndpi_tls_cert_validity_too_long" },

  /* NDPI_TLS_SUSPICIOUS_EXTENSION */
  { { flow_alert_ndpi_tls_suspicious_extension, alert_category_security }, "ndpi_tls_suspicious_extension" },

  /* NDPI_TLS_FATAL_ALERT */
  { { flow_alert_ndpi_tls_fatal_alert, alert_category_other }, "ndpi_tls_fatal_alert" },

  /* NDPI_SUSPICIOUS_ENTROPY */
  { { flow_alert_ndpi_suspicious_entropy, alert_category_security }, "ndpi_suspicious_entropy" },

  /* NDPI_CLEAR_TEXT_CREDENTIALS */
  { { flow_alert_ndpi_clear_text_credentials, alert_category_security }, "ndpi_clear_text_credentials" },

  /* NDPI_DNS_LARGE_PACKET */
  { { flow_alert_ndpi_dns_large_packet, alert_category_security }, "ndpi_dns_large_packet" },

  /* NDPI_DNS_FRAGMENTED */
  { { flow_alert_ndpi_dns_fragmented, alert_category_security }, "ndpi_dns_fragmented" },

  /* NDPI_INVALID_CHARACTERS */
  { { flow_alert_ndpi_invalid_characters, alert_category_security }, "ndpi_invalid_characters" },

  /* NDPI_POSSIBLE_EXPLOIT */
  { { flow_alert_ndpi_possible_exploit, alert_category_security }, "ndpi_possible_exploit" },

  /* NDPI_TLS_CERTIFICATE_ABOUT_TO_EXPIRE */
  { { flow_alert_ndpi_tls_certificate_about_to_expire, alert_category_security }, "ndpi_tls_certificate_about_to_expire" },

  /* NDPI_PUNYCODE_IDN */
  { { flow_alert_ndpi_punicody_idn, alert_category_security }, "ndpi_punicody_idn"	},

  /* NDPI_ERROR_CODE_DETECTED */
  { { flow_alert_ndpi_error_code_detected, alert_category_network }, "ndpi_error_code_detected" },

  /* NDPI_HTTP_CRAWLER_BOT */
  { { flow_alert_ndpi_http_crawler_bot, alert_category_network }, "ndpi_http_crawler_bot" },

  /* NDPI_ANONYMOUS_SUBSCRIBER */
  { { flow_alert_ndpi_anonymous_subscriber, alert_category_security }, "ndpi_anonymous_subscriber" },

  /* NDPI_UNIDIRECTIONAL_TRAFFIC */
  { { flow_alert_ndpi_unidirectional_traffic, alert_category_network }, "ndpi_unidirectional_traffic" },

  /* NDPI_HTTP_OBSOLETE_SERVER */
  { { flow_alert_ndpi_http_obsolete_server, alert_category_security }, "ndpi_http_obsolete_server" },
};

/* **************************************************** */

bool FlowRiskAlerts::isRiskUndefined(ndpi_risk_enum risk) {
  /*
    A risk is unhandled by this class if either it exceeds the number of available risks
    or if it has not been mapped to the risk_enum_to_alert_type array.
   */
  return(risk >= NDPI_MAX_RISK || risk_enum_to_alert_type[risk].alert_type.id == flow_alert_normal);
}

/* **************************************************** */

void FlowRiskAlerts::checkUndefinedRisks() {
  for(int risk_id = 1; risk_id < NDPI_MAX_RISK; risk_id++) {
    if(risk_enum_to_alert_type[risk_id].alert_type.id == flow_alert_normal)
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[!] nDPI risk %u/%s has not been defined in ntopng", risk_id, ndpi_risk2str((ndpi_risk_enum)risk_id));
    else
      ntop->getTrace()->traceEvent(TRACE_INFO, "Risk %u/%s handled", risk_id, ndpi_risk2str((ndpi_risk_enum)risk_id));
  }
}

/* **************************************************** */

bool FlowRiskAlerts::lua(lua_State* vm) {
  lua_newtable(vm);

  for(int risk_id = 1; risk_id < NDPI_MAX_RISK; risk_id++) {
    ndpi_risk_enum risk = (ndpi_risk_enum)risk_id;
    FlowAlertType fat = FlowRiskAlerts::getFlowRiskAlertType(risk);

    if(fat.id != flow_alert_normal) {
      const char *alert_name =  FlowRiskAlerts::getCheckName(risk);

      lua_newtable(vm);

      lua_push_uint64_table_entry(vm, "alert_id", fat.id);
      lua_push_uint64_table_entry(vm, "category", fat.category);
      lua_push_str_table_entry(vm, "risk_name", ndpi_risk2str(risk));

      lua_pushstring(vm, alert_name);
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  }

  return true;
}

/* **************************************************** */

FlowAlertType FlowRiskAlerts::getFlowRiskAlertType(ndpi_risk_enum risk) {
  if(isRiskUndefined(risk))
    return risk_enum_to_alert_type[NDPI_NO_RISK].alert_type;
  else
    return risk_enum_to_alert_type[risk].alert_type;
}

/* **************************************************** */

const char * FlowRiskAlerts::getCheckName(ndpi_risk_enum risk) {
  if(isRiskUndefined(risk))
    return risk_enum_to_alert_type[NDPI_NO_RISK].alert_lua_name;
  else
    return risk_enum_to_alert_type[risk].alert_lua_name;
}
