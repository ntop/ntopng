--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require ("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"

-- #################################################################

-- NOTE: this module is always enabled
local script = {
   -- Script category
   category = user_scripts.script_categories.network,

   nedge_exclude = true,
   l4_proto = "tcp",
   three_way_handshake_ok = true,

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.tcp_issues_generic",
      i18n_description = "flow_callbacks_config.tcp_issues_generic_description",
   }
}

local min_issues_count = 10 -- At least 10 packets
local normal_issues_ratio = 10	-- 1/10
local severe_issues_ratio = 3	-- 1/3

-- #################################################################

local function check_tcp_issues(now)
   local is_client = false -- Does the client have TCP issues?
   local is_server = false -- Does the server have TCP issues?
   local is_severe = false -- Whether the exceeded one is the severe threshold

   -- Client -> Server
   local cli_issues = flow.getClientTCPIssues()
   if(cli_issues > min_issues_count) then
      local cli2srv_pkts = flow.getPacketsSent()

      if((cli_issues * severe_issues_ratio) > cli2srv_pkts) then
	 is_client = true
	 is_severe = true
      elseif((cli_issues * normal_issues_ratio) > cli2srv_pkts) then
	 is_client = true
      end
   end

   -- Server -> Client
   local srv_issues = flow.getServerTCPIssues()
   if(srv_issues > min_issues_count) then
      local srv2cli_pkts = flow.getPacketsRcvd()

      if((srv_issues * severe_issues_ratio) > srv2cli_pkts) then
	 is_server = true
	 is_severe = true
      elseif((srv_issues * normal_issues_ratio) > srv2cli_pkts) then
	 is_server = true
      end
   end

   -- Now it's time to generate the alert, it either the client or the server has issues

   if is_client or is_server then
      if is_severe then
         local tcp_severe_connection_issues_type = flow_consts.status_types.status_tcp_severe_connection_issues.create(
            flow.getTCPStats(),
            flow.getPacketsSent(),
            flow.getPacketsRcvd(),
            true, -- Severe issues
            is_client,
            is_server
         )

         alerts_api.trigger_status(tcp_severe_connection_issues_type, alert_severities.warning, 20, 20, 20)

      else
         local tcp_severe_connection_issues_type = flow_consts.status_types.status_tcp_severe_connection_issues.create(
            flow.getTCPStats(),
            flow.getPacketsSent(),
            flow.getPacketsRcvd(),
            false, -- Issues are NOT severe
            is_client,
            is_server
         )

         alerts_api.trigger_status(tcp_severe_connection_issues_type, alert_severities.warning, 10, 10, 10)
      end
   end
end

-- #################################################################

script.hooks.flowEnd = check_tcp_issues
script.hooks.periodicUpdate = check_tcp_issues

-- #################################################################

return script
