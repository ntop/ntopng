--
-- (C) 2020-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = {
   flow_alert_normal                          = 0,
   flow_alert_blacklisted                     = 1,
   flow_alert_blacklisted_country             = 2,
   flow_alert_flow_blocked                    = 3,
   flow_alert_data_exfiltration               = 4,
   flow_alert_device_protocol_not_allowed     = 5,
   flow_alert_dns_data_exfiltration           = 6,
   flow_alert_dns_invalid_query               = 7,
   flow_alert_elephant_flow                   = 8,
   flow_alert_elephant_remote_to_local        = 9,  -- No longer used, can be recycled
   flow_alert_external                        = 10,
   flow_alert_longlived                       = 11,
   flow_alert_low_goodput                     = 12,
   flow_alert_malicious_signature             = 13,
   flow_alert_internals                       = 14,
   flow_alert_potentially_dangerous           = 15,
   flow_alert_remote_to_remote                = 16,
   flow_alert_suspicious_tcp_probing          = 17, -- No longer used, can be recycled
   flow_alert_suspicious_tcp_syn_probing      = 18, -- No longer used, can be recycled
   flow_alert_tcp_connection_issues           = 19,
   flow_alert_tcp_connection_refused          = 20,
   flow_alert_tcp_severe_connection_issues    = 21,
   flow_alert_tls_certificate_expired         = 22,
   flow_alert_tls_certificate_mismatch        = 23,
   flow_alert_tls_old_protocol_version        = 24,
   flow_alert_tls_unsafe_ciphers              = 25,
   flow_alert_udp_unidirectional              = 26,
   flow_alert_web_mining                      = 27,
   flow_alert_tls_certificate_selfsigned      = 28,
   flow_alert_suspicious_file_transfer        = 29,
   flow_alert_known_proto_on_non_std_port     = 30,
   flow_alert_flow_risk                       = 31,
   flow_alert_unexpected_dhcp_server          = 32,
   flow_alert_unexpected_dns_server           = 33,
   flow_alert_unexpected_smtp_server          = 34,
   flow_alert_unexpected_ntp_server           = 35,
   flow_alert_zero_tcp_window                 = 36,
   flow_alert_iec_invalid_transition          = 37,
   flow_alert_remote_to_local_insecure_proto  = 38,
   flow_alert_ndpi_url_possible_xss           = 39,
   flow_alert_ndpi_url_possible_sql_injection = 40,
   flow_alert_ndpi_url_possible_rce_injection = 41,
   flow_alert_ndpi_http_suspicious_user_agent = 42,
   flow_alert_ndpi_http_numeric_ip_host       = 43,
   flow_alert_ndpi_http_suspicious_url        = 44,
   flow_alert_ndpi_http_suspicious_header     = 45,
   flow_alert_ndpi_tls_not_carrying_https     = 46,
   flow_alert_ndpi_suspicious_dga_domain      = 47,
   flow_alert_ndpi_malformed_packet           = 48,
   flow_alert_ndpi_ssh_obsolete               = 49,
   flow_alert_ndpi_smb_insecure_version       = 50,
   flow_alert_ndpi_tls_suspicious_esni_usage  = 51,
   flow_alert_ndpi_unsafe_protocol            = 52,
   flow_alert_ndpi_dns_suspicious_traffic     = 53,
   flow_alert_ndpi_tls_missing_sni            = 54,
   flow_alert_iec_unexpected_type_id          = 55,
   flow_alert_tcp_no_data_exchanged           = 56,
   flow_alert_remote_access                   = 57,
   flow_alert_lateral_movement                = 58,
   flow_alert_periodicity_changed             = 59,
   -- NOTE: for flow alerts not not go beyond the size of Bitmap alert_map inside Flow.h (currently 128)
}

-- ##############################################

return flow_alert_keys

-- ##############################################
