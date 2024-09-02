--
-- (C) 2020-24 - ntop.org
--

require "ndpi_flow_alert_keys"

-- ##############################################

--[[
    typedef enum {
        NDPI_NO_RISK = 0,
        NDPI_BINARY_APPLICATION_TRANSFER,4
        NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT,5
        NDPI_TLS_SELFSIGNED_CERTIFICATE,6
        NDPI_TLS_WEAK_CIPHER,8
        NDPI_TLS_CERTIFICATE_EXPIRED,9
        NDPI_TLS_CERTIFICATE_MISMATCH, /* 10 */
    }
]]


local ndpi_flow_alert_keys = {
    flow_alert_ndpi_url_possible_xss                = 1,
    flow_alert_ndpi_url_possible_sql_injection      = 2,
    flow_alert_ndpi_url_possible_rce_injection      = 3,
    flow_alert_ndpi_tls_old_protocol_version        = 7,
    flow_alert_ndpi_http_suspicious_user_agent      = 11,
    flow_alert_ndpi_numeric_ip_host                 = 12,
    flow_alert_ndpi_http_suspicious_url             = 13,
    flow_alert_ndpi_http_suspicious_header          = 14,
    flow_alert_ndpi_tls_not_carrying_https          = 15,
    flow_alert_ndpi_suspicious_dga_domain           = 16,
    flow_alert_ndpi_malformed_packet                = 17,
    flow_alert_ndpi_ssh_obsolete_client             = 18,
    flow_alert_ndpi_ssh_obsolete_server             = 19,
    flow_alert_ndpi_smb_insecure_version            = 20,
    flow_alert_ndpi_tls_suspicious_esni_usage       = 21,
    flow_alert_ndpi_unsafe_protocol                 = 22,
    flow_alert_ndpi_dns_suspicious_traffic          = 23,
    flow_alert_ndpi_tls_missing_sni                 = 24,
    flow_alert_ndpi_http_suspicious_content         = 25,
    flow_alert_ndpi_risky_asn                       = 26,
    flow_alert_ndpi_risky_domain                    = 27,
    flow_alert_ndpi_malicious_fingerprint           = 28,
    flow_alert_ndpi_malicious_sha1_certificate      = 29,
    flow_alert_ndpi_desktop_or_file_sharing_session = 30,
    flow_alert_ndpi_tls_uncommon_alpn               = 31,
    flow_alert_ndpi_tls_cert_validity_too_long      = 32,
    flow_alert_ndpi_tls_suspicious_extension        = 33,
    flow_alert_ndpi_tls_fatal_alert                 = 34,
    flow_alert_ndpi_suspicious_entropy              = 35,
    flow_alert_ndpi_clear_text_credentials          = 36,
    flow_alert_ndpi_dns_large_packet                = 37,
    flow_alert_ndpi_dns_fragmented                  = 38,
    flow_alert_ndpi_invalid_characters              = 39,
    flow_alert_ndpi_possible_exploit                = 40,
    flow_alert_ndpi_tls_certificate_about_to_expire = 41,
    flow_alert_ndpi_punicody_idn                    = 42,
    flow_alert_ndpi_error_code_detected             = 43,
    flow_alert_ndpi_http_crawler_bot                = 44,
    flow_alert_ndpi_anonymous_subscriber            = 45,
    flow_alert_ndpi_unidirectional_traffic          = 46,
    flow_alert_ndpi_http_obsolete_server            = 47,
    flow_alert_ndpi_periodic_flow                   = 48,
    flow_alert_ndpi_minor_issues                    = 49,
    flow_alert_ndpi_tcp_issues                      = 50,
    flow_alert_ndpi_fully_encrypted                 = 51,
    flow_alert_ndpi_tls_alpn_sni_mismatch           = 52,
    flow_alert_ndpi_malware_host_contacted          = 53,
    flow_alert_ndpi_binary_data_transfer            = 54,
    flow_alert_ndpi_probing_attempt                 = 55
}

-- ##############################################

return ndpi_flow_alert_keys

-- ##############################################
