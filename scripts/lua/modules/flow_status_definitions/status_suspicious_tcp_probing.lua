--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

return {
  status_key = status_keys.ntopng.status_suspicious_tcp_probing,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_suspicious_activity,
  i18n_title = "flow_details.suspicious_tcp_probing",
}
