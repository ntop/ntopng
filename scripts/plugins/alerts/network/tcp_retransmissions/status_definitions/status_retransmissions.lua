
local alert_consts = require ("alert_consts")
local status_keys = require "flow_keys"

return {
   status_key = status_keys.ntopng.status_too_many_retransmissions,
   alert_severity = alert_consts.alert_severities.warning,
   alert_type = alert_consts.alert_types.alert_retransmissions,
   i18n_title = "Too many retransmissions",
   i18n_description = "The number of retransmitted flow packets is too high",
}
