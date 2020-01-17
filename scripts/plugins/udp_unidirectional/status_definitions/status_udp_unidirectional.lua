--
-- (C) 2019-20 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  prio = 195,
  alert_severity = alert_consts.alert_severities.info,
  alert_type = alert_consts.alert_types.alert_udp_unidirectional,
  i18n_title = "flow_details.udp_unidirectional"
}
