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
	local retry_flag = false
	
	if (c2s_retransmissions ~= nil and cli_sent_packets ~= nil) then
		local perc_retransmissions_on_sent = c2s_retransmissions/cli_sent_packets
		 
		if (cli_sent_packets ~= 0 and perc_retrasmissions_on_sent >= 0.2) then
			client_score = 2
			server_score = 10
			retry_flag = true
		end
	end
	if (s2c_retransmissions ~= nil and cli_rcvd_packets ~= nil) then
		local perc_retransmissions_on_rcvd = s2c_retransmissions/cli_rcvd_packets

		if (cli_rcvd_packets ~= 0 and perc_retransmissions_on_rcvd >= 0.2) then
			client_score = 10
			server_score = 2
			retry_flag = true
		end
	end

	if retry_flag then
		flow.triggerStatus(
			flow_consts.status_types.status_retransmissions.create(
				flow_consts.status_types.status_retransmissions.alert_severity,
				tcp_stats
			),
			100, -- flow score subject to change
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

