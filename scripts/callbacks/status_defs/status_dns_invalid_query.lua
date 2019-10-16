--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 11,
  relevance = 30,
  prio = 400,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_suspicious_activity,
  i18n_title = "flow_details.dns_invalid_query"
}
