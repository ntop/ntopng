--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 15,
  relevance = 50,
  prio = 350,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_web_mining,
  i18n_title = "flow_details.web_mining_detected"
}
