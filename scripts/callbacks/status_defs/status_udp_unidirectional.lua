--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 28,
  relevance = 50,
  prio = 195,
  alert_severity = alert_consts.alert_severities.info,
  alert_type = alert_consts.alert_types.alert_suspicious_activity,
  i18n_title = "flow_details.udp_unidirectional"
}
