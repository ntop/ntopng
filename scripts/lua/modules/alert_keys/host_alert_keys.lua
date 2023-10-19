--
-- (C) 2020-22 - ntop.org
--

-- ##############################################

-- Keep in sync with ntop_typedefs.h HostAlertTypeEnum
local host_alert_keys = {
  host_alert_normal                      =  0,
  host_alert_smtp_server_contacts        =  1,
  host_alert_dns_server_contacts         =  2,
  host_alert_ntp_server_contacts         =  3,
  host_alert_flow_flood                  =  4,
  host_alert_syn_scan                    =  5,
  host_alert_syn_flood                   =  6,
  host_alert_domain_names_contacts       =  7,
  host_alert_p2p_traffic                 =  8,
  host_alert_dns_traffic                 =  9,
  host_alert_flows_anomaly               = 10,
  host_alert_score_anomaly               = 11,
  host_alert_remote_connection           = 12,
  host_alert_host_log                    = 13,
  host_alert_dangerous_host              = 14,
  host_alert_ntp_traffic                 = 15,
  host_alert_countries_contacts          = 16,
  host_alert_score_threshold             = 17,
  host_alert_icmp_flood                  = 18,
  host_alert_pkt_threshold               = 19,
  host_alert_scan_detected               = 20,
  host_alert_fin_scan                    = 21,
  host_alert_dns_flood                   = 22,
  host_alert_snmp_flood                  = 23,
  host_alert_custom_lua_script           = 24,
  host_alert_rst_scan                    = 25,
  host_alert_traffic_volume              = 26,
  host_alert_external_script             = 27,
  
  -- NOTE: Keep in sync with HostAlertTypeEnum in ntop_typedefs.h
}

-- ##############################################

return host_alert_keys

-- ##############################################
