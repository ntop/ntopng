--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 24,
  relevance = 30,
  prio = 640,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_flow_misbehaviour,
  i18n_title = "flow_details.data_exfiltration"
}
