--
-- (C) 2020 - ntop.org
--

-- ##############################################

-- This is the ZERO pen used for ntopng builtin alerts found in the alert_keys.ntopng table below
-- Some ZERO PENs are also available to users when creating user plugins. They are specified in the alert_keys.user table below.
-- Other PENs may be specified by users when creating custom plugins.
local NO_PEN = 0

-- ##############################################

local alert_keys = {
   ntopng = {
      alert_blacklisted_country            = {NO_PEN, 1},
      alert_broadcast_domain_too_large     = {NO_PEN, 2},
      alert_device_connection              = {NO_PEN, 3},
      alert_device_disconnection           = {NO_PEN, 4},
      alert_device_protocol_not_allowed    = {NO_PEN, 5},
      alert_dropped_alerts                 = {NO_PEN, 6},
      alert_external                       = {NO_PEN, 7},
      alert_flow_blacklisted               = {NO_PEN, 8},
      alert_flow_blocked                   = {NO_PEN, 9},
      alert_flow_misbehaviour              = {NO_PEN, 10}, -- No longer used
      alert_flows_flood                    = {NO_PEN, 11},
      alert_ghost_network                  = {NO_PEN, 12},
      alert_host_pool_connection           = {NO_PEN, 13},
      alert_host_pool_disconnection        = {NO_PEN, 14},
      alert_influxdb_dropped_points        = {NO_PEN, 15},
      alert_influxdb_error                 = {NO_PEN, 16},
      alert_influxdb_export_failure        = {NO_PEN, 17},
      alert_internals                      = {NO_PEN, 18},
      alert_ip_outsite_dhcp_range          = {NO_PEN, 19},
      alert_list_download_failed           = {NO_PEN, 20},
      alert_login_failed                   = {NO_PEN, 21},
      alert_mac_ip_association_change      = {NO_PEN, 22},
      alert_malicious_signature            = {NO_PEN, 23},
      alert_misbehaving_flows_ratio        = {NO_PEN, 24},
      alert_misconfigured_app              = {NO_PEN, 25},
      alert_new_device                     = {NO_PEN, 26}, -- No longer used
      alert_nfq_flushed                    = {NO_PEN, 27},
      alert_none                           = {NO_PEN, 28}, -- No longer used
      alert_periodic_activity_not_executed = {NO_PEN, 29},
      alert_am_threshold_cross             = {NO_PEN, 30},
      alert_port_duplexstatus_change       = {NO_PEN, 31},
      alert_port_errors                    = {NO_PEN, 32},
      alert_port_load_threshold_exceeded   = {NO_PEN, 33},
      alert_port_mac_changed               = {NO_PEN, 34},
      alert_port_status_change             = {NO_PEN, 35},
      alert_potentially_dangerous_protocol = {NO_PEN, 36},
      alert_process_notification           = {NO_PEN, 37},
      alert_quota_exceeded                 = {NO_PEN, 38},
      alert_remote_to_remote               = {NO_PEN, 39},
      alert_request_reply_ratio            = {NO_PEN, 40},
      alert_slow_periodic_activity         = {NO_PEN, 41},
      alert_slow_purge                     = {NO_PEN, 42},
      alert_snmp_device_reset              = {NO_PEN, 43},
      alert_snmp_topology_changed          = {NO_PEN, 44},
      alert_suspicious_activity            = {NO_PEN, 45}, -- No longer used
      alert_tcp_syn_flood                  = {NO_PEN, 46},
      alert_tcp_syn_scan                   = {NO_PEN, 47},
      alert_test_failed                    = {NO_PEN, 48},
      alert_threshold_cross                = {NO_PEN, 49},
      alert_too_many_drops                 = {NO_PEN, 50},
      alert_udp_unidirectional             = {NO_PEN, 51},
      alert_unresponsive_device            = {NO_PEN, 52},
      alert_user_activity                  = {NO_PEN, 53},
      alert_user_script_calls_drops        = {NO_PEN, 54},
      alert_web_mining                     = {NO_PEN, 55},
      alert_connection_issues              = {NO_PEN, 56},
      alert_suspicious_file_transfer       = {NO_PEN, 57},
      alert_known_proto_on_non_std_port    = {NO_PEN, 58},
      alert_host_log                       = {NO_PEN, 59},
      alert_attack_mitigation_via_snmp     = {NO_PEN, 60},
      alert_iec104_error                   = {NO_PEN, 61},
      alert_flow_risk                      = {NO_PEN, 62},
      alert_unexpected_dns_server          = {NO_PEN, 63},
      alert_unexpected_smtp_server         = {NO_PEN, 64},
      alert_unexpected_dhcp_server         = {NO_PEN, 65},
      alert_unexpected_ntp_server          = {NO_PEN, 66},
      alert_too_many_retransmissions       = {NO_PEN, 67}, -- No longer used
      alert_lateral_movement               = {NO_PEN, 68},
      alert_list_download_succeeded        = {NO_PEN, 69},
      alert_no_if_activity                 = {NO_PEN, 70}, -- scripts/plugins/alerts/internals/no_if_activity
      alert_zero_tcp_window                = {NO_PEN, 71},
      alert_flow_low_goodput               = {NO_PEN, 72},
      alert_unexpected_new_device          = {NO_PEN, 73}, -- scripts/plugins/alerts/security/unexpected_new_device
      alert_shell_script_executed          = {NO_PEN, 74}, -- scripts/plugins/endpoints/shell_alert_endpoint
      alert_periodicity_update             = {NO_PEN, 75}, -- pro/scripts/enterprise_l_plugins/alerts/network/periodicity_update
      alert_dns_positive_error_ratio       = {NO_PEN, 76}, -- pro/scripts/enterprise_l_plugins/alerts/network/dns_positive_error_ratio
      alert_elephant_local_to_remote       = {NO_PEN, 77},
      alert_elephant_remote_to_local       = {NO_PEN, 78},
      alert_longlived                      = {NO_PEN, 79},
      alert_tls_old_protocol_version       = {NO_PEN, 80},
      alert_tls_certificate_mismatch       = {NO_PEN, 81},
      alert_tls_certificate_expired        = {NO_PEN, 82},
      alert_tls_unsafe_ciphers             = {NO_PEN, 83},
      alert_tls_certificate_selfsigned     = {NO_PEN, 84},
      alert_data_exfiltration              = {NO_PEN, 85},
      alert_dns_data_exfiltration          = {NO_PEN, 86},
      alert_tcp_connection_refused         = {NO_PEN, 87},
      alert_suspicious_tcp_syn_probing     = {NO_PEN, 88},
      alert_suspicious_tcp_probing         = {NO_PEN, 89},
      alert_dns_invalid_query              = {NO_PEN, 90},
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
