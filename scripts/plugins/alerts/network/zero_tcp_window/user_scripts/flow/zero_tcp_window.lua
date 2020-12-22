--
-- (C) 2020 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_severities = require "alert_severities"
local user_scripts = require("user_scripts")
local flow_consts  = require("flow_consts")

local script

-- #################################################################

script = {
  -- Script category
  category = user_scripts.script_categories.network,

  -- NB atm working only for packet interfaces
  packet_interface_only = true,
  l4_proto = "tcp",
  
  -- NOTE: hooks defined below
  hooks = {},  

  gui = {
    i18n_title        = "zero_tcp_window.zero_tcp_window_title",
    i18n_description  = "zero_tcp_window.zero_tcp_window_description",
  }
}

-- #################################################################

local function check_tcp_window(now)
   local zerowin = flow.isTcpZeroWinAlert()

   if(zerowin.client or zerowin.server) then
      local high_score = 30
      local low_score  = 5
      local client_score
      local server_score

      -- Client -> Server
      if(zerowin.client) then
	 client_score = high_score
	 server_score = low_score
      end

      -- Server -> Client
      if(zerowin.server) then
	 client_score = low_score
	 server_score = high_score
      end

      -- Now it's time to generate the alert   
      local zero_tcp_window_type = flow_consts.status_types.status_zero_tcp_window.create(
         zerowin.client,
         zerowin.server
      )

      alerts_api.trigger_status(zero_tcp_window_type, alert_severities.warning, client_score, server_score, high_score)   
   end
end

-- #################################################################

script.hooks.periodicUpdate = check_tcp_window
script.hooks.flowEnd        = check_tcp_window

-- #################################################################



return script
