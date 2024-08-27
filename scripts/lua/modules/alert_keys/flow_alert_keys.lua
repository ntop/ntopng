--
-- (C) 2020-24 - ntop.org
--

-- ##############################################

-- Keep in sync with ntop_typedefs.h FlowAlertTypeEnum and ndpi_flow_alert_keys.lua
local flow_alert_keys = {
   flow_alert_normal                               = 0,
   flow_alert_blacklisted                          = 1,
   flow_alert_blacklisted_country                  = 2,
   flow_alert_flow_blocked                         = 3,
   flow_alert_data_exfiltration                    = 4,
   flow_alert_device_protocol_not_allowed          = 5,
   flow_alert_dns_data_exfiltration                = 6,
   flow_alert_dns_invalid_query                    = 7,
   flow_alert_elephant_flow                        = 8,
   flow_alert_blacklisted_client_contact           = 9,
   flow_alert_external                             = 10,
   flow_alert_longlived                            = 11,
   flow_alert_low_goodput                          = 12,
   flow_alert_blacklisted_server_contact           = 13,
   flow_alert_internals                            = 14,
   flow_alert_notused_3                            = 15, -- No longer used, can be recycled
   flow_alert_remote_to_remote                     = 16,
   flow_alert_notused_4                            = 17, -- No longer used, can be recycled
   flow_alert_notused_5                            = 18, -- No longer used, can be recycled
   flow_alert_tcp_packets_issues                   = 19,
   flow_alert_tcp_connection_refused               = 20,
   flow_alert_tcp_severe_connection_issues         = 21,
   flow_alert_tls_certificate_expired              = 22,
   flow_alert_tls_certificate_mismatch             = 23,
   flow_alert_tls_unsafe_ciphers                   = 25,
   flow_alert_web_mining                           = 27,
   flow_alert_tls_certificate_selfsigned           = 28,
   flow_alert_binary_application_transfer          = 29,
   flow_alert_known_proto_on_non_std_port          = 30,
   flow_alert_flow_risk                            = 31,
   flow_alert_unexpected_dhcp_server               = 32,
   flow_alert_unexpected_dns_server                = 33,
   flow_alert_unexpected_smtp_server               = 34,
   flow_alert_unexpected_ntp_server                = 35,
   flow_alert_zero_tcp_window                      = 36,
   flow_alert_iec_invalid_transition               = 37,
   flow_alert_remote_to_local_insecure_proto       = 38,
   flow_alert_iec_unexpected_type_id               = 55,
   flow_alert_tcp_no_data_exchanged                = 56,
   flow_alert_remote_access                        = 57,
   flow_alert_lateral_movement                     = 58,
   flow_alert_periodicity_changed                  = 59,
   flow_alert_broadcast_non_udp_traffic            = 67,
   flow_alert_iec_invalid_command_transition       = 74,
   flow_alert_connection_failed                    = 75,
   flow_alert_unidirectional_traffic               = 77,
   flow_alert_custom_lua_script                    = 87,
   flow_alert_vlan_bidirectional_traffic           = 91,
   flow_alert_rare_destination                     = 92,
   flow_alert_modbus_unexpected_function_code      = 93,
   flow_alert_modbus_too_many_exceptions           = 94,
   flow_alert_modbus_invalid_transition            = 95,
   flow_alert_tcp_flow_reset                       = 100,
   
   -- NOTE: do not go beyond the size of the alert_map bitmal inside Flow.h (currently 128)
}

-- ##############################################

return flow_alert_keys

-- ##############################################
