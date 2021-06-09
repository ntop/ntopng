--
-- (C) 2020-21 - ntop.org
--

-- ##############################################

local host_alert_keys = {
  host_alert_normal                      =  0,
  host_alert_smtp_server_contacts        =  1,
  host_alert_dns_server_contacts         =  2,
  host_alert_ntp_server_contacts         =  3,
  host_alert_flow_flood                  =  4,
  host_alert_syn_scan                    =  5,
  host_alert_syn_flood                   =  6,
  host_alert_score                       =  7,
  host_alert_p2p_traffic                 =  8,
  host_alert_dns_traffic                 =  9,
  host_alert_flows_anomaly               = 10,
  host_alert_score_anomaly               = 11,
  host_alert_remote_connection           = 12,
  host_alert_host_log                    = 13,
  host_alert_dangerous_host              = 14,
   
   -- NOTE: Keep in sync with HostAlertTypeEnum in ntop_typedefs.h
}

-- ##############################################

return host_alert_keys

-- ##############################################
