--
-- (C) 2020-22 - ntop.org
--

-- ##############################################

-- Use for 'other' keys that don't overlap with other entities.
-- Eventually, every alert listed below will have its own entity defined and other will disappear.
-- Currently, it is necessary to handle the transition
local OTHER_BASE_KEY = 4096

-- ##############################################

local other_alert_keys = {
   alert_device_connection              =  OTHER_BASE_KEY + 1 ,
   alert_device_disconnection           =  OTHER_BASE_KEY + 2 ,
   alert_dropped_alerts                 =  OTHER_BASE_KEY + 3 ,
   alert_gateway_unreachable            =  OTHER_BASE_KEY + 4 ,
   alert_flow_flood                     =  OTHER_BASE_KEY + 5 , -- No longer used, check alert_flow_flood_attacker and alert_flow_flood_victim
   alert_ghost_network                  =  OTHER_BASE_KEY + 6 ,
   alert_host_pool_connection           =  OTHER_BASE_KEY + 7 , -- No longer used
   alert_host_pool_disconnection        =  OTHER_BASE_KEY + 8 ,
   alert_influxdb_dropped_points        =  OTHER_BASE_KEY + 9 ,
   alert_influxdb_error                 =  OTHER_BASE_KEY + 10,
   alert_influxdb_export_failure        =  OTHER_BASE_KEY + 11,
   alert_ip_outsite_dhcp_range          =  OTHER_BASE_KEY + 13,
   alert_list_download_failed           =  OTHER_BASE_KEY + 14,
   alert_login_failed                   =  OTHER_BASE_KEY + 15,
   alert_mac_ip_association_change      =  OTHER_BASE_KEY + 16,
   alert_misbehaving_flows_ratio        =  OTHER_BASE_KEY + 17,
   alert_misconfigured_app              =  OTHER_BASE_KEY + 18,
   alert_new_device                     =  OTHER_BASE_KEY + 19, -- No longer used
   alert_nfq_flushed                    =  OTHER_BASE_KEY + 20,
   alert_none                           =  OTHER_BASE_KEY + 21, -- No longer used
   alert_periodic_activity_not_executed =  OTHER_BASE_KEY + 22,
   alert_am_threshold_cross             =  OTHER_BASE_KEY + 23,
   alert_port_duplexstatus_change       =  OTHER_BASE_KEY + 24,
   alert_port_errors                    =  OTHER_BASE_KEY + 25,
   alert_port_load_threshold_exceeded   =  OTHER_BASE_KEY + 26,
   alert_port_mac_changed               =  OTHER_BASE_KEY + 27,
   alert_port_status_change             =  OTHER_BASE_KEY + 28,
   alert_process_notification           =  OTHER_BASE_KEY + 29,
   alert_quota_exceeded                 =  OTHER_BASE_KEY + 30,
   alert_request_reply_ratio            =  OTHER_BASE_KEY + 31,
   alert_slow_periodic_activity         =  OTHER_BASE_KEY + 32,
   alert_slow_purge                     =  OTHER_BASE_KEY + 33,
   alert_snmp_device_reset              =  OTHER_BASE_KEY + 34,
   alert_snmp_topology_changed          =  OTHER_BASE_KEY + 35,
   alert_suspicious_activity            =  OTHER_BASE_KEY + 36, -- No longer used
   alert_tcp_syn_flood                  =  OTHER_BASE_KEY + 37, -- No longer used, check alert_tcp_syn_flood_attacker and alert_tcp_syn_flood_victim
   alert_tcp_syn_scan                   =  OTHER_BASE_KEY + 38, -- No longer used, check alert_tcp_syn_scan_attacker and alert_tcp_syn_scan_victim
   alert_test_failed                    =  OTHER_BASE_KEY + 39,
   alert_threshold_cross                =  OTHER_BASE_KEY + 40,
   alert_too_many_drops                 =  OTHER_BASE_KEY + 41,
   alert_unresponsive_device            =  OTHER_BASE_KEY + 42,
   alert_user_activity                  =  OTHER_BASE_KEY + 43,
   alert_check_calls_drops              =  OTHER_BASE_KEY + 44, -- No longer used
   alert_host_log                       =  OTHER_BASE_KEY + 45, -- No longer used (moved to the host)
   alert_attack_mitigation_via_snmp     =  OTHER_BASE_KEY + 46,
   alert_iec104_error                   =  OTHER_BASE_KEY + 47, -- No longer used
   alert_lateral_movement               =  OTHER_BASE_KEY + 48, -- No longer user (moved to the flows)
   alert_list_download_succeeded        =  OTHER_BASE_KEY + 49,
   alert_no_if_activity                 =  OTHER_BASE_KEY + 50, 
   alert_device_connection_disconnection =  OTHER_BASE_KEY + 51, 
   alert_shell_script_executed          =  OTHER_BASE_KEY + 52, 
   alert_periodicity_update             =  OTHER_BASE_KEY + 53, -- No longer user (moved to the flows)
   alert_dns_positive_error_ratio       =  OTHER_BASE_KEY + 54, 
   alert_fail2ban_executed              =  OTHER_BASE_KEY + 55, 
   alert_flow_flood_attacker            =  OTHER_BASE_KEY + 56,
   alert_flow_flood_victim              =  OTHER_BASE_KEY + 57,
   alert_tcp_syn_flood_attacker         =  OTHER_BASE_KEY + 58,
   alert_tcp_syn_flood_victim           =  OTHER_BASE_KEY + 59,
   alert_tcp_syn_scan_attacker          =  OTHER_BASE_KEY + 60,
   alert_tcp_syn_scan_victim            =  OTHER_BASE_KEY + 61,
   alert_contacted_peers                =  OTHER_BASE_KEY + 62,
   alert_contacts_anomaly               =  OTHER_BASE_KEY + 63, 
   alert_score_anomaly_client           =  OTHER_BASE_KEY + 64, 
   alert_score_anomaly_server           =  OTHER_BASE_KEY + 65, 
   alert_active_flows_anomaly_client    =  OTHER_BASE_KEY + 66, 
   alert_active_flows_anomaly_server    =  OTHER_BASE_KEY + 67, 
   alert_broadcast_domain_too_large     =  OTHER_BASE_KEY + 68,
   alert_ngi_trust_event                =  OTHER_BASE_KEY + 69,
   alert_excessive_traffic              =  OTHER_BASE_KEY + 70, -- No longer used
   alert_behavior_anomaly               =  OTHER_BASE_KEY + 71, 
   alert_ids_ips_jail_add               =  OTHER_BASE_KEY + 72, 
   alert_ids_ips_jail_remove            =  OTHER_BASE_KEY + 73, 
   alert_port_too_many_macs             =  OTHER_BASE_KEY + 74,
   alert_network_discovery_executed     =  OTHER_BASE_KEY + 75,
   alert_port_mac_appeared              =  OTHER_BASE_KEY + 76,
   alert_port_mac_disappeared           =  OTHER_BASE_KEY + 77,
   alert_network_score_per_host         =  OTHER_BASE_KEY + 78,
   alert_dhcp_storm                     =  OTHER_BASE_KEY + 79,
   alert_snmp_interface_errors          =  OTHER_BASE_KEY + 80,
   alert_snmp_device_traffic_change     =  OTHER_BASE_KEY + 81,
   alert_local_host_blacklisted         =  OTHER_BASE_KEY + 82,
   alert_network_issues                 =  OTHER_BASE_KEY + 83,
   alert_network_rule_threshold_cross   =  OTHER_BASE_KEY + 84,
   alert_snmp_interface_threshold_crossed = OTHER_BASE_KEY + 85,
}

-- ##############################################

return other_alert_keys

-- ##############################################
