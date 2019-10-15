--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 28,
  relevance = 50,
  prio = 190,
  severity = alert_consts.alert_severities.info,
  alert_type = alert_consts.alert_types.suspicious_activity,
  i18n_title = "flow_details.udp_unidirectional"
}
