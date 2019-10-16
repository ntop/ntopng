--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 9,
  relevance = 10,
  prio = 340,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_suspicious_activity,
  i18n_title = "flow_details.tcp_connection_refused"
}
