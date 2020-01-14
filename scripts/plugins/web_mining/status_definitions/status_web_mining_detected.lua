--
-- (C) 2019-20 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 15,
  cli_score = 50,
  srv_score = 10,
  prio = 350,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_web_mining,
  i18n_title = "flow_details.web_mining_detected"
}
