/*
 *
 * (C) 2013-21 - ntop.org
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

const FlowAlertTypeExtended FlowRiskAlerts::risk_enum_to_alert_type[NDPI_MAX_RISK] = {
  [NDPI_NO_RISK] = {
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_URL_POSSIBLE_XSS] = {
    .alert_type = { flow_alert_ndpi_url_possible_xss, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_URL_POSSIBLE_SQL_INJECTION] = {
    .alert_type = { flow_alert_ndpi_url_possible_sql_injection, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_URL_POSSIBLE_RCE_INJECTION] = {
    .alert_type = { flow_alert_ndpi_url_possible_rce_injection, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_BINARY_APPLICATION_TRANSFER] =
  {
    .alert_type = { flow_alert_suspicious_file_transfer, alert_category_security },
    .alert_lua_name = "suspicious_file_transfer"
  },
  [NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT] = {
    .alert_type = { flow_alert_known_proto_on_non_std_port, alert_category_security },
    .alert_lua_name = ""
  },
    [NDPI_TLS_SELFSIGNED_CERTIFICATE] = {
    .alert_type = { flow_alert_tls_certificate_selfsigned, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_TLS_OBSOLETE_VERSION] = {
    .alert_type = { flow_alert_tls_old_protocol_version, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_TLS_WEAK_CIPHER] = {
    .alert_type = { flow_alert_tls_unsafe_ciphers, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_TLS_CERTIFICATE_EXPIRED] = {
    .alert_type =  { flow_alert_tls_certificate_expired,  alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_TLS_CERTIFICATE_MISMATCH] = {
    .alert_type = { flow_alert_tls_certificate_mismatch, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_HTTP_SUSPICIOUS_USER_AGENT] = {
    .alert_type = { flow_alert_ndpi_http_suspicious_user_agent, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_HTTP_NUMERIC_IP_HOST] = {
    .alert_type = { flow_alert_ndpi_http_numeric_ip_host, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_HTTP_SUSPICIOUS_URL] = {
    .alert_type = { flow_alert_ndpi_http_suspicious_url, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_HTTP_SUSPICIOUS_HEADER] = {
    .alert_type = { flow_alert_ndpi_http_suspicious_header, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_TLS_NOT_CARRYING_HTTPS] = {
    .alert_type = { flow_alert_ndpi_tls_not_carrying_https, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_SUSPICIOUS_DGA_DOMAIN] = {
    .alert_type = { flow_alert_ndpi_suspicious_dga_domain, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_MALFORMED_PACKET] = {
    .alert_type = { flow_alert_ndpi_malformed_packet, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_SSH_OBSOLETE_CLIENT_VERSION_OR_CIPHER] = {
    .alert_type = { flow_alert_ndpi_ssh_obsolete_client,  alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_SSH_OBSOLETE_SERVER_VERSION_OR_CIPHER] = {
    .alert_type = { flow_alert_ndpi_ssh_obsolete_server, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_SMB_INSECURE_VERSION] = {
    .alert_type = { flow_alert_ndpi_smb_insecure_version, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_TLS_SUSPICIOUS_ESNI_USAGE] = {
    .alert_type = { flow_alert_ndpi_tls_suspicious_esni_usage, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_UNSAFE_PROTOCOL] = {
    .alert_type = { flow_alert_ndpi_unsafe_protocol, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_DNS_SUSPICIOUS_TRAFFIC] = {
    .alert_type = { flow_alert_ndpi_dns_suspicious_traffic, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_TLS_MISSING_SNI] = {
    .alert_type = { flow_alert_ndpi_tls_missing_sni, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_HTTP_SUSPICIOUS_CONTENT] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_RISKY_ASN] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_RISKY_DOMAIN] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_MALICIOUS_JA3] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_MALICIOUS_SHA1_CERTIFICATE] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_DESKTOP_OR_FILE_SHARING_SESSION] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_TLS_UNCOMMON_ALPN] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_TLS_CERT_VALIDITY_TOO_LONG] = {
    .alert_type = { flow_alert_ndpi_suspicious_dga_domain, alert_category_security },
    .alert_lua_name = ""
  },
  [NDPI_TLS_SUSPICIOUS_EXTENSION] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_TLS_FATAL_ALERT] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_SUSPICIOUS_ENTROPY] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
  [NDPI_CLEAR_TEXT_CREDENTIALS] = { /* Unhandled */
    .alert_type = { flow_alert_normal, alert_category_other },
    .alert_lua_name = ""
  },
};

/* **************************************************** */

FlowAlertType FlowRiskAlerts::getFlowRiskAlertType(ndpi_risk_enum risk) {
  return risk_enum_to_alert_type[risk].alert_type;
}

/* **************************************************** */

void FlowRiskAlerts::checkUnhandledRisks() {
  for(int risk_id = 1; risk_id < NDPI_MAX_RISK; risk_id++) {
    if(risk_enum_to_alert_type[risk_id].alert_type.id == flow_alert_normal)
      ntop->getTrace()->traceEvent(TRACE_INFO, "nDPI risk unhanded by ntopng [risk: %u/%s]", risk_id, ndpi_risk2str((ndpi_risk_enum)risk_id));
    else
      ntop->getTrace()->traceEvent(TRACE_INFO, "Risk handled [risk: %u/%s]", risk_id, ndpi_risk2str((ndpi_risk_enum)risk_id));
  }
}

/* **************************************************** */
