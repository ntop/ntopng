--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param tcp_stats A lua table with TCP stats obtained with flow.getTCPStats
-- @param cli2srv_pkts Number of packets sent from the client to the server
-- @param srv2cli_pkts Number of packets sent from the server to the client
-- @param is_severe A boolean indicating whether connection issues are severe
-- @param client_issues A boolean indicating if the client has connection issues
-- @param server_issues A boolean indicating if the server has connection issues
-- @return A table with the alert built
local function createConnectionIssues(tcp_stats, cli2srv_pkts, srv2cli_pkts, is_severe, client_issues, server_issues)
   local built = {
      alert_type_params = {
	 tcp_stats = tcp_stats,
	 cli2srv_pkts = cli2srv_pkts,
	 srv2cli_pkts = srv2cli_pkts,
	 is_severe = is_severe,
	 client_issues = client_issues,
	 server_issues = server_issues,
      },
   }

   return built
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_connection_issues,
  i18n_title = "alerts_dashboard.connection_issues",
  icon = "fas fa-exclamation",
  creator = createConnectionIssues,
}
