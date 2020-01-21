--
-- (C) 2019-20 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  prio = 50,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_internals,
  i18n_title = "flow_details.not_purged"
}
