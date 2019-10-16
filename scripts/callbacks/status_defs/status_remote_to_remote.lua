--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_id = 12,
  relevance = 50,
  prio = 190,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_remote_to_remote,
  i18n_title = "flow_details.remote_to_remote",
}
