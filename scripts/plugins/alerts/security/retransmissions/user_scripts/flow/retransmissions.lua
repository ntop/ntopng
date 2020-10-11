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
		-- I still need to modify the en.lua file
		i18n_title = "Retransmitions flow Alert",
		i18n_description = "Alert when there are too many packets retrasmitted in the flow",
	}
}

-- ############################################

local function retransmissions_check(now)
	--srv2cli.retransmissions, cli2srv.retransmissions
	local tcp_stats = flow.getTCPStats()
	local c2s_retransmissions = tcp_stats["cli2srv.retransmissions"] 
	local s2c_retransmissions = tcp_stats["srv2cli.retransmissions"]

	local cli_sent_packets = flow.getPacketsSent()
	local cli_rcvd_packets = flow.getPacketsRcvd()

	local client_score
	local server_score
	local retry_flag = false

	if (c2s_retransmissions ~= nil and cli_sent_packets ~= nil) then
		local perc_retryonsent = c2s_retransmissions/cli_sent_packets
		-- io.write ("CLT: retry: ", c2s_retransmissions, "; mandati: ", cli_sent_packets, "; perc: ", perc_retryonsent,";\n") 
		if (cli_sent_packets ~= 0 and perc_retryonsent >= 0.2) then
			-- Send alert and decrease score of server (The scores are subject to change)
			client_score = 2
			server_score = 10
			retry_flag = true
		end
	end
	if (s2c_retransmissions ~= nil and cli_rcvd_packets ~= nil) then
		local perc_retryonrcvd = s2c_retransmissions/cli_rcvd_packets
		-- io.write ("SRV: retry: ", s2c_retransmissions, "; mandati: ", cli_rcvd_packets, "; perc: ", perc_retryonrcvd,";\n") 
		if (cli_rcvd_packets ~= 0 and perc_retryonrcvd >= 0.2) then
			-- Send alert and decrease score of client (The scores are subject to change)
			client_score = 10
			server_score = 2
			retry_flag = true
		end
	end

	if retry_flag then
		-- io.write ("Sending an Alert\n") 
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

	-- io.write("---------\n")
end

-- ############################################

-- both hooks use this function so if a flow get checked even if he doesn't end soon
script.hooks.flowEnd = retransmissions_check
script.hooks.periodicUpdate = retransmissions_check

-- ############################################

return script

