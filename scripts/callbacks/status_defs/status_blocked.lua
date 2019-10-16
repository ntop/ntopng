--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 14,
  relevance = 50,
  prio = 150,
  alert_severity = alert_consts.alert_severities.info,
  alert_type = alert_consts.alert_types.alert_flow_blocked,
  i18n_title = "flow_details.flow_blocked_by_bridge"
}
