--
-- (C) 2020 - ntop.org
--

-- ##############################################

local flow_keys = {
   ntopng = {
      status_normal                       = 0,
      status_blacklisted                  = 1,
      status_blacklisted_country          = 2,
      status_blocked                      = 3,
      status_data_exfiltration            = 4,
      status_device_protocol_not_allowed  = 5,
      status_dns_data_exfiltration        = 6,
      status_dns_invalid_query            = 7,
      status_elephant_local_to_remote     = 8,
      status_elephant_remote_to_local     = 9,
      status_external_alert               = 10,
      status_longlived                    = 11,
      status_low_goodput                  = 12,
      status_malicious_signature          = 13,
      status_not_purged                   = 14,
      status_potentially_dangerous        = 15,
      status_remote_to_remote             = 16,
      status_suspicious_tcp_probing       = 17,
      status_suspicious_tcp_syn_probing   = 18,
      status_tcp_connection_issues        = 19,
      status_tcp_connection_refused       = 20,
      status_tcp_severe_connection_issues = 21,
      status_tls_certificate_expired      = 22,
      status_tls_certificate_mismatch     = 23,
      status_tls_old_protocol_version     = 24,
      status_tls_unsafe_ciphers           = 25,
      status_udp_unidirectional           = 26,
      status_web_mining_detected          = 27,
      status_tls_certificate_selfsigned   = 28,
      status_suspicious_file_transfer     = 29,
      status_known_proto_on_non_std_port  = 30,
      status_flow_risk                    = 31,
      status_unexpected_dhcp_server       = 32,
      status_unexpected_dns_server        = 33,
      status_unexpected_smtp_server       = 34,
      status_unexpected_ntp_server        = 35,
      status_zero_tcp_window              = 36,
      status_iec_invalid_transition       = 37,
      status_remote_to_local_insecure_proto  = 38,
      status_ndpi_url_possible_xss        = 39,
      status_ndpi_url_possible_sql_injection = 40,
      status_ndpi_url_possible_rce_injection = 41,
      status_ndpi_http_suspicious_user_agent = 42,
      status_ndpi_http_numeric_ip_host    = 43,
      status_ndpi_http_suspicious_url     = 44,
      status_ndpi_http_suspicious_header  = 45,
      status_ndpi_tls_not_carrying_https  = 46,
      status_ndpi_suspicious_dga_domain   = 47,
      status_ndpi_malformed_packet        = 48,
      status_ndpi_ssh_obsolete            = 49,
      status_ndpi_smb_insecure_version    = 50,
      status_ndpi_tls_suspicious_esni_usage  = 51,
      status_ndpi_unsafe_protocol         = 52,
      status_ndpi_dns_suspicious_traffic  = 53,
      status_ndpi_tls_missing_sni         = 54,
      
      -- Add here additional flow statuses when writing ntopng plugins.
      -- User plugins should use statuses under key user.
      -- WARNING: no not overlap with user; MAXIMUM status is 58 unless
      -- class Bitmap in Flow has been extended to accomodate more than
      -- 64 bits
   },
   user = {
      status_user_01                      = 59,
      status_user_02                      = 60,
      status_user_03                      = 61,
      status_user_04                      = 62,
      status_user_05                      = 63, -- Seems this is not seen by Lua, use until 62
      -- WARNING: do not add any extra status greater than 63
      -- unless class Bitmap inside Flow has been extended to
      -- accomodate more than 64 bits.
   },
}

-- ##############################################

return flow_keys

-- ##############################################
