--
-- (C) 2020 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require "alert_consts"
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
  periodic_update_seconds = 60,
  
  -- NOTE: hooks defined below
  hooks = {},  

  gui = {
    i18n_title        = "zero_tcp_window.zero_tcp_window_title",
    i18n_description  = "zero_tcp_window.zero_tcp_window_description",
  }
}

-- #################################################################

local function check_tcp_window(now)
  local is_client = false -- Does the client has TCP issues?
  local is_server = false -- Does the server has TCP issues?

  if(false) then
    tprint("=================================")
    tprint("Into periodic update")
    tprint(flow.getTcpWndCli2SrvCheck())
    tprint(flow.getTcpWndCli2Srv())
    tprint(flow.getTcpWndSrv2CliCheck())
    tprint(flow.getTcpWndSrv2Cli())
  end

  -- Client -> Server
  if(flow.getTcpWndCli2SrvCheck() == false) then
    if(flow.getTcpWndCli2Srv() == true) then
      flow.setTcpWndCli2SrvCheck()
      is_client = true
    end
  end

  -- Server -> Client
  if(flow.getTcpWndSrv2CliCheck() == false) then
    if(flow.getTcpWndSrv2Cli() == true) then
      flow.setTcpWndSrv2CliCheck()
      is_server = true
    end
  end

  -- Now it's time to generate the alert, it either the client or the server has issues

  if is_client or is_server then
    flow.triggerStatus(
      flow_consts.status_types.status_zero_tcp_window.create(
	 flow_consts.status_types.status_zero_tcp_window.alert_severity,
        is_client,
        is_server
     ),
     10 --[[ flow score]],
     10 --[[ cli score ]],
     10 --[[ srv score ]]
    )
  end
end

-- #################################################################

script.hooks.periodicUpdate = check_tcp_window
script.hooks.flowEnd        = check_tcp_window

-- #################################################################



return script
