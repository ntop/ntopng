--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 8,
  relevance = 10,
  prio = 10,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_flow_misbehaviour,
  i18n_title = "flow_details.flow_emitted"
}
