--
-- (C) 2020-21 - ntop.org
--

-- ##############################################

local host_alert_keys = {
   host_alert_normal                    =  0,
   host_alert_dns_requests_errors_ratio =  1,
   host_alert_replies_requests_ratio    =  2,
   host_alert_smtp_server_contacts      =  3,
   host_alert_dns_server_contacts       =  4,
   host_alert_ntp_server_contacts       =  5,
   host_alert_flow_flood                =  6,
   host_alert_syn_scan                  =  7,
   host_alert_syn_flood                 =  8,
   host_alert_score                     =  9,
   host_alert_p2p_traffic               = 10,
   host_alert_dns_traffic               = 11,
   -- NOTE: for host alerts not not go beyond the size of Bitmap16 alert_map inside Host.h
}

-- ##############################################

return host_alert_keys

-- ##############################################
