--
-- (C) 2020 - ntop.org
--

local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"

-- #######################################################

local function zeroTcpWindow(ifid, alert, zero_tcp_window_checks)
  if(zero_tcp_window_checks.is_client) then
    return(i18n("zero_tcp_window.status_zero_tcp_window_description" .. "Flow direction: Client -> Server")) -- .. flow.name)) Need to concatenate the name/id/infos of the flow to the description
  else
    return(i18n("zero_tcp_window.status_zero_tcp_window_description" .. "Flow direction: Server -> Client")) -- .. flow.name)) Need to concatenate the name/id/infos of the flow to the description
  end
end

-- ##############################################

local function createZeroTcpWindow(alert_severity, alert_granularity, is_server, is_client)
  local zero_tcp_window_type = {
     alert_granularity = alert_granularity,
     alert_severity = alert_severity,
     alert_type_params = {
      is_server = is_server,
      is_client = is_client
     }
  }

  return zero_tcp_window_type
end

-- #######################################################

return {
  status_keys = status_keys.ntopng.status_zero_tcp_window,
  alert_severity = alert_consts.alert_severities.warning,
  alert_type = alert_consts.alert_types.alert_connection_issues,
  i18n_title = "zero_tcp_window.stats_zero_tcp_window_title",
  i18n_description = zeroTcpWindow,
  icon = "fas fa-arrow-circle-up",
  creator = createZeroTcpWindow,
}
