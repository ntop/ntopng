--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 25,
  relevance = 30,
  prio = 470,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_potentially_dangerous_protocol,
  i18n_title = "flow_details.ssl_old_protocol_version"
}
