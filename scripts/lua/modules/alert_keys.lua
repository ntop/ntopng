--
-- (C) 2020-21 - ntop.org
--

-- ##############################################

-- This is the ZERO pen used for ntopng builtin alerts found in the alert_keys.ntopng table below
-- Some ZERO PENs are also available to users when creating user plugins. They are specified in the alert_keys.user table below.
-- Other PENs may be specified by users when creating custom plugins.
local NO_PEN = 0

-- ##############################################

local BASE_ID = 1024 -- This is the first id reserved for non-flow-statuses.

-- ##############################################

local alert_keys = {
   ntopng = {
      -- First 1024 (0 to 1023) IDs reserved for flow status alerts.
      -- Flow statuses are a Bitmap of 128 bits. 1024 is just to keep a safe margin
      -- and possibly enlarge Bitmap in the future
      -- NOTE: Keep them in sync with ntop_typedefs.h FlowAlertType
      alert_normal                          = {NO_PEN, 0},
      alert_blacklisted                     = {NO_PEN, 1},
      alert_blacklisted_country             = {NO_PEN, 2},
      alert_flow_blocked                    = {NO_PEN, 3},
      alert_data_exfiltration               = {NO_PEN, 4},
      alert_device_protocol_not_allowed     = {NO_PEN, 5},
      alert_dns_data_exfiltration           = {NO_PEN, 6},
      alert_dns_invalid_query               = {NO_PEN, 7},
      alert_elephant_flow                   = {NO_PEN, 8},
      alert_elephant_remote_to_local        = {NO_PEN, 9},  -- No longer used, can be recycled
      alert_external                        = {NO_PEN, 10},
      alert_longlived                       = {NO_PEN, 11},
      alert_low_goodput                     = {NO_PEN, 12},
      alert_malicious_signature             = {NO_PEN, 13},
      alert_internals                       = {NO_PEN, 14},
      alert_potentially_dangerous           = {NO_PEN, 15},
      alert_remote_to_remote                = {NO_PEN, 16},
      alert_suspicious_tcp_probing          = {NO_PEN, 17},
      alert_suspicious_tcp_syn_probing      = {NO_PEN, 18},
      alert_tcp_connection_issues           = {NO_PEN, 19},
      alert_tcp_connection_refused          = {NO_PEN, 20},
      alert_tcp_severe_connection_issues    = {NO_PEN, 21},
      alert_tls_certificate_expired         = {NO_PEN, 22},
      alert_tls_certificate_mismatch        = {NO_PEN, 23},
      alert_tls_old_protocol_version        = {NO_PEN, 24},
      alert_tls_unsafe_ciphers              = {NO_PEN, 25},
      alert_udp_unidirectional              = {NO_PEN, 26},
      alert_web_mining                      = {NO_PEN, 27},
      alert_tls_certificate_selfsigned      = {NO_PEN, 28},
      alert_suspicious_file_transfer        = {NO_PEN, 29},
      alert_known_proto_on_non_std_port     = {NO_PEN, 30},
      alert_flow_risk                       = {NO_PEN, 31},
      alert_unexpected_dhcp_server          = {NO_PEN, 32},
      alert_unexpected_dns_server           = {NO_PEN, 33},
      alert_unexpected_smtp_server          = {NO_PEN, 34},
      alert_unexpected_ntp_server           = {NO_PEN, 35},
      alert_zero_tcp_window                 = {NO_PEN, 36},
      alert_iec_invalid_transition          = {NO_PEN, 37},
      alert_remote_to_local_insecure_proto  = {NO_PEN, 38},
      alert_ndpi_url_possible_xss           = {NO_PEN, 39},
      alert_ndpi_url_possible_sql_injection = {NO_PEN, 40},
      alert_ndpi_url_possible_rce_injection = {NO_PEN, 41},
      alert_ndpi_http_suspicious_user_agent = {NO_PEN, 42},
      alert_ndpi_http_numeric_ip_host       = {NO_PEN, 43},
      alert_ndpi_http_suspicious_url        = {NO_PEN, 44},
      alert_ndpi_http_suspicious_header     = {NO_PEN, 45},
      alert_ndpi_tls_not_carrying_https     = {NO_PEN, 46},
      alert_ndpi_suspicious_dga_domain      = {NO_PEN, 47},
      alert_ndpi_malformed_packet           = {NO_PEN, 48},
      alert_ndpi_ssh_obsolete               = {NO_PEN, 49},
      alert_ndpi_smb_insecure_version       = {NO_PEN, 50},
      alert_ndpi_tls_suspicious_esni_usage  = {NO_PEN, 51},
      alert_ndpi_unsafe_protocol            = {NO_PEN, 52},
      alert_ndpi_dns_suspicious_traffic     = {NO_PEN, 53},
      alert_ndpi_tls_missing_sni            = {NO_PEN, 54},
      alert_iec_unexpected_type_id          = {NO_PEN, 55},
      
      -- NOTE: for flow alerts not not go beyond the size of Bitmap alert_map inside Flow.h (currently 128)

      --
      -- Here we have statuses >= 1024 that are reserved for non-flows
      --
      alert_broadcast_domain_too_large     = {NO_PEN, BASE_ID     },
      alert_device_connection              = {NO_PEN, BASE_ID + 1 },
      alert_device_disconnection           = {NO_PEN, BASE_ID + 2 },
      alert_dropped_alerts                 = {NO_PEN, BASE_ID + 3 },
      alert_flow_misbehaviour              = {NO_PEN, BASE_ID + 4 }, -- No longer used
      alert_flows_flood                    = {NO_PEN, BASE_ID + 5 }, -- No longer used, check alert_flows_flood_attacker and alert_flows_flood_victim
      alert_ghost_network                  = {NO_PEN, BASE_ID + 6 },
      alert_host_pool_connection           = {NO_PEN, BASE_ID + 7 },
      alert_host_pool_disconnection        = {NO_PEN, BASE_ID + 8 },
      alert_influxdb_dropped_points        = {NO_PEN, BASE_ID + 9 },
      alert_influxdb_error                 = {NO_PEN, BASE_ID + 10},
      alert_influxdb_export_failure        = {NO_PEN, BASE_ID + 11},
      alert_ip_outsite_dhcp_range          = {NO_PEN, BASE_ID + 13},
      alert_list_download_failed           = {NO_PEN, BASE_ID + 14},
      alert_login_failed                   = {NO_PEN, BASE_ID + 15},
      alert_mac_ip_association_change      = {NO_PEN, BASE_ID + 16},
      alert_misbehaving_flows_ratio        = {NO_PEN, BASE_ID + 17},
      alert_misconfigured_app              = {NO_PEN, BASE_ID + 18},
      alert_new_device                     = {NO_PEN, BASE_ID + 19}, -- No longer used
      alert_nfq_flushed                    = {NO_PEN, BASE_ID + 20},
      alert_none                           = {NO_PEN, BASE_ID + 21}, -- No longer used
      alert_periodic_activity_not_executed = {NO_PEN, BASE_ID + 22},
      alert_am_threshold_cross             = {NO_PEN, BASE_ID + 23},
      alert_port_duplexstatus_change       = {NO_PEN, BASE_ID + 24},
      alert_port_errors                    = {NO_PEN, BASE_ID + 25},
      alert_port_load_threshold_exceeded   = {NO_PEN, BASE_ID + 26},
      alert_port_mac_changed               = {NO_PEN, BASE_ID + 27},
      alert_port_status_change             = {NO_PEN, BASE_ID + 28},
      alert_process_notification           = {NO_PEN, BASE_ID + 29},
      alert_quota_exceeded                 = {NO_PEN, BASE_ID + 30},
      alert_request_reply_ratio            = {NO_PEN, BASE_ID + 31},
      alert_slow_periodic_activity         = {NO_PEN, BASE_ID + 32},
      alert_slow_purge                     = {NO_PEN, BASE_ID + 33},
      alert_snmp_device_reset              = {NO_PEN, BASE_ID + 34},
      alert_snmp_topology_changed          = {NO_PEN, BASE_ID + 35},
      alert_suspicious_activity            = {NO_PEN, BASE_ID + 36}, -- No longer used
      alert_tcp_syn_flood                  = {NO_PEN, BASE_ID + 37}, -- No longer used, check alert_tcp_syn_flood_attacker and alert_tcp_syn_flood_victim
      alert_tcp_syn_scan                   = {NO_PEN, BASE_ID + 38}, -- No longer used, check alert_tcp_syn_scan_attacker and alert_tcp_syn_scan_victim
      alert_test_failed                    = {NO_PEN, BASE_ID + 39},
      alert_threshold_cross                = {NO_PEN, BASE_ID + 40},
      alert_too_many_drops                 = {NO_PEN, BASE_ID + 41},
      alert_unresponsive_device            = {NO_PEN, BASE_ID + 42},
      alert_user_activity                  = {NO_PEN, BASE_ID + 43},
      alert_user_script_calls_drops        = {NO_PEN, BASE_ID + 44},
      alert_host_log                       = {NO_PEN, BASE_ID + 45},
      alert_attack_mitigation_via_snmp     = {NO_PEN, BASE_ID + 46},
      alert_iec104_error                   = {NO_PEN, BASE_ID + 47}, -- No longer used
      alert_lateral_movement               = {NO_PEN, BASE_ID + 48},
      alert_list_download_succeeded        = {NO_PEN, BASE_ID + 49},
      alert_no_if_activity                 = {NO_PEN, BASE_ID + 50}, -- scripts/plugins/alerts/internals/no_if_activity
      alert_unexpected_new_device          = {NO_PEN, BASE_ID + 51}, -- scripts/plugins/alerts/security/unexpected_new_device
      alert_shell_script_executed          = {NO_PEN, BASE_ID + 52}, -- scripts/plugins/endpoints/shell_alert_endpoint
      alert_periodicity_update             = {NO_PEN, BASE_ID + 53}, -- pro/scripts/enterprise_l_plugins/alerts/network/periodicity_update
      alert_dns_positive_error_ratio       = {NO_PEN, BASE_ID + 54}, -- pro/scripts/enterprise_l_plugins/alerts/network/dns_positive_error_ratio
      alert_fail2ban_executed              = {NO_PEN, BASE_ID + 55}, -- pro/scripts/pro_plugins/endpoints/fail2ban_alert_endpoint
      alert_flows_flood_attacker           = {NO_PEN, BASE_ID + 56},
      alert_flows_flood_victim             = {NO_PEN, BASE_ID + 57},
      alert_tcp_syn_flood_attacker         = {NO_PEN, BASE_ID + 58},
      alert_tcp_syn_flood_victim           = {NO_PEN, BASE_ID + 59},
      alert_tcp_syn_scan_attacker          = {NO_PEN, BASE_ID + 60},
      alert_tcp_syn_scan_victim            = {NO_PEN, BASE_ID + 61},
      alert_contacted_peers                = {NO_PEN, BASE_ID + 62},
      alert_contacts_anomaly               = {NO_PEN, BASE_ID + 63}, -- scripts/plugins/alerts/security/unexpected_host_behaviour/modules/contacted_hosts_behaviour
      alert_score_anomaly_client           = {NO_PEN, BASE_ID + 64}, -- scripts/plugins/alerts/security/unexpected_host_behaviour/modules/score_behaviour
      alert_score_anomaly_server           = {NO_PEN, BASE_ID + 65}, -- scripts/plugins/alerts/security/unexpected_host_behaviour/modules/score_behaviour
      alert_active_flows_anomaly_client    = {NO_PEN, BASE_ID + 66}, -- scripts/plugins/alerts/security/unexpected_host_behaviour/modules/active_flows_behaviour
      alert_active_flows_anomaly_server    = {NO_PEN, BASE_ID + 67}, -- scripts/plugins/alerts/security/unexpected_host_behaviour/modules/active_flows_behaviour
      
      -- Add here additional keys for alerts generated
      -- by ntopng plugins
      -- WARNING: make sure integers do NOT OVERLAP with
      -- user alerts
   },
   user = {
      alert_user_01                        = {NO_PEN, 32768},
      alert_user_02                        = {NO_PEN, 32769},
      alert_user_03                        = {NO_PEN, 32770},
      alert_user_04                        = {NO_PEN, 32771},
      alert_user_05                        = {NO_PEN, 32772},
      -- Add here additional keys generated by
      -- user plugin
   },
}

-- ##############################################

-- A table to keep the reverse mapping between integer alert keys and string alert keys
local alert_id_to_alert_key = {}

for _, ntopng_user in ipairs({"ntopng", "user"}) do
   for cur_key_string, cur_key_array in pairs(alert_keys[ntopng_user]) do
      local cur_pen, cur_id = cur_key_array[1], cur_key_array[2]

      if not alert_id_to_alert_key[cur_pen] then
	 alert_id_to_alert_key[cur_pen] = {}
      end

      alert_id_to_alert_key[cur_pen][cur_id] = cur_key_string
   end
end

-- ##############################################

-- @brief Parse an alert key, check if it is compliant with the expected format, and returns the parsed key and a status message
--
--        Alert keys must be specified as an array of two numbers as {<PEN>, <pen_key>}:
--          - <PEN> is an integer greater than or equal to zero and less than 65535 and can be used to uniquely identify an enterprise.
--            A <PEN> equal to zero is reserved for ntopng builtin alerts.
--          - <pen_key> is an integer greater than or equal to zero and less than 65535 which is combined with <PEN>
--            to uniquely identify an alert. The resulting alert key is a 32bit integer where the 16 most significant bits
--            reserved for the <PEN> and the 16 least significant bits reserved for the <pen_key>.
--
--        Any other format is discarded and the parse function fails.
--
-- @param key The alert key to be parsed.
--            Examples:
--              `alert_keys.ntopng.alert_connection_issues`
--              `alert_keys.user.alert_user_01`
--              `{312, 513}`.
--              `{0, alert_keys.user.alert_user_01}`. In this case where PEN equals zero only the <pen_key> is taken
--
-- @return An integer corresponding to the parsed alert key and a status message which equals "OK" when no error occurred during parsing.
--
function alert_keys.parse_alert_key(key)
   local parsed_alert_key
   local status = "OK"

   if type(key) == "table" and #key == 2 then
      -- A table, let's parse it with PEN and key
      local pen, pen_key = key[1], key[2]

      if not type(pen) == "number" or pen < 0 or pen >= 0xFFFF then
	 -- PEN is out of bounds or not a number
	 status = "Invalid PEN specified. PEN must be between 0 and 65535."
      elseif not type(pen_key) == "number" or pen_key < 0 or pen_key >= 0xFFFF then
	 -- pen_key is out of bounds or not a number
	 status = "Invalid alert key specified. Alert key must be between 0 and 65535."
      elseif pen == 0 then
	 -- PEN is zero, this is a builtin key and we need to verify its exsistance
	 if not alert_id_to_alert_key[pen] or not alert_id_to_alert_key[pen][pen_key] then
	    status = "Alert key specified is not among the available alert keys."
	 else
	    parsed_alert_key = pen_key
	 end
      else
	 -- PEN in the 16 MSB and pen_key in the 16 LSB
	 parsed_alert_key = (pen << 16) + pen_key
      end
   else
      status = "Unexpected alert key type."
   end

   return parsed_alert_key, status
end

-- ##############################################

return alert_keys

-- ##############################################
