--
-- (C) 2019-20 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

return {
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_remote_to_remote,
  i18n_title = "flow_details.remote_to_remote",
}
