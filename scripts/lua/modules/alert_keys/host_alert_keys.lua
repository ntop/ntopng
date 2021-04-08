--
-- (C) 2020-21 - ntop.org
--

-- ##############################################

local host_alert_keys = {
   host_alert_normal                      =  0,
   host_alert_dns_replies_requests_ratio  =  1,
   host_alert_smtp_server_contacts        =  2,
   host_alert_dns_server_contacts         =  3,
   host_alert_ntp_server_contacts         =  4,
   host_alert_flow_flood                  =  5,
   host_alert_syn_scan                    =  6,
   host_alert_syn_flood                   =  7,
   host_alert_score                       =  8,
   host_alert_p2p_traffic                 =  9,
   host_alert_dns_traffic                 = 10,
   -- NOTE: for host alerts not not go beyond the size of Bitmap16 alert_map inside Host.h
}

-- ##############################################

return host_alert_keys

-- ##############################################
