--
-- (C) 2019-20 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 20,
  relevance = 0,
  prio = 50,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_connection_issues,
  i18n_title = "flow_details.not_purged"
}
