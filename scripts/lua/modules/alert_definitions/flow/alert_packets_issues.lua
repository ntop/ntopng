--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_tcp_packets_issues = classes.class(alert)

-- ##############################################

alert_tcp_packets_issues.meta = {
  alert_key = flow_alert_keys.flow_alert_tcp_packets_issues,
  i18n_title = "flow_checks_config.tcp_packets_issues",
  icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param tcp_stats A lua table with TCP stats obtained with flow.getTCPStats
-- @param cli2srv_pkts Number of packets sent from the client to the server
-- @param srv2cli_pkts Number of packets sent from the server to the client
-- @param is_severe A boolean indicating whether connection issues are severe
-- @param client_issues A boolean indicating if the client has connection issues
-- @param server_issues A boolean indicating if the server has connection issues
-- @return A table with the alert built
function alert_tcp_packets_issues:init()
  -- Call the parent constructor
  self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_tcp_packets_issues.format(ifid, alert, alert_type_params)
  local msg = ''
  tprint(alert_type_params)
  if alert_type_params.lost > alert_type_params.lost_threshold then
    msg = i18n("flow_checks_config.tcp_packets_issues_alert", { type = 'loss', value = alert_type_params.lost, threshold = alert_type_params.lost_threshold })
  elseif alert_type_params.retransmission > alert_type_params.retransmission_threshold then
    msg = i18n("flow_checks_config.tcp_packets_issues_alert", { type = 'retransmission', value = alert_type_params.retransmission, threshold = alert_type_params.retransmission_threshold })
  elseif alert_type_params.out_of_order > alert_type_params.out_of_order_threshold then
    msg = i18n("flow_checks_config.tcp_packets_issues_alert", { type = 'out of order', value = alert_type_params.out_of_order, threshold = alert_type_params.out_of_order_threshold })
  end

  return msg
end

-- #######################################################

return alert_tcp_packets_issues
