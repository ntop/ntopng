--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local status_keys = require "status_keys"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_connection_issues = classes.class(alert)

-- ##############################################

alert_connection_issues.meta = {
   status_key = status_keys.ntopng.status_tcp_connection_issues,
   alert_key = alert_keys.ntopng.alert_connection_issues,
   i18n_title = "alerts_dashboard.connection_issues",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param tcp_stats A lua table with TCP stats obtained with flow.getTCPStats
-- @param cli2srv_pkts Number of packets sent from the client to the server
-- @param srv2cli_pkts Number of packets sent from the server to the client
-- @param is_severe A boolean indicating whether connection issues are severe
-- @param client_issues A boolean indicating if the client has connection issues
-- @param server_issues A boolean indicating if the server has connection issues
-- @return A table with the alert built
function alert_connection_issues:init(tcp_stats, cli2srv_pkts, srv2cli_pkts, is_severe, client_issues, server_issues)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      tcp_stats = tcp_stats,
	 cli2srv_pkts = cli2srv_pkts,
	 srv2cli_pkts = srv2cli_pkts,
	 is_severe = is_severe,
	 client_issues = client_issues,
	 server_issues = server_issues,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_connection_issues.format(ifid, alert, alert_type_params)
   format_utils.formatConnectionIssues(alert_type_params)
end

-- #######################################################

return alert_connection_issues
