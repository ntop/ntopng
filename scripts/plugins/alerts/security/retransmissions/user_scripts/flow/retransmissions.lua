--
-- (C) 2019-20 ntop.org
--

local user_scripts = require("user_scripts")
local flow_consts = require("flow_consts")

-- ############################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security,

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "retransmissions.retransmissions_alert_title",
      i18n_description = "retransmissions.retransmissions_alert_description",
   }
}

-- ############################################

local function retransmissions_check(now)
   local tcp_stats = flow.getTCPStats()
   local c2s_retransmissions = tcp_stats["cli2srv.retransmissions"] 
   local s2c_retransmissions = tcp_stats["srv2cli.retransmissions"]
   local cli_sent_packets = flow.getPacketsSent()
   local cli_rcvd_packets = flow.getPacketsRcvd()
   local client_score
   local server_score
   local emit_retransmission_alert = false
   local threshold_percentage = 0.2 -- 20%

   if(cli_sent_packets > 0) then
      local perc_retransmissions_on_sent = c2s_retransmissions/cli_sent_packets
      
      if(perc_retransmissions_on_sent >= threshold_percentage) then
	 client_score = 2
	 server_score = 10
	 emit_retransmission_alert = true
      end
   end

   if(cli_rcvd_packets > 0) then
      local perc_retransmissions_on_rcvd = s2c_retransmissions/cli_rcvd_packets
      
      if(perc_retransmissions_on_rcvd >= threshold_percentage) then
	 client_score = 10
	 server_score = 2
	 emit_retransmission_alert = true
      end
   end

   if(emit_retransmission_alert) then
      flow.triggerStatus(
	 flow_consts.status_types.status_retransmissions.create(
	    flow_consts.status_types.status_retransmissions.alert_severity,
	    tcp_stats
	 ),
	 10, -- flow score subject to change
	 client_score,
	 server_score
      )
   end

end

-- ############################################

script.hooks.flowEnd = retransmissions_check
script.hooks.periodicUpdate = retransmissions_check 

-- ############################################

return script

