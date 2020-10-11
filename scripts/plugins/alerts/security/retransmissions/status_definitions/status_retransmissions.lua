local alert_consts = require ("alert_consts")
local status_keys = require "flow_keys"

return {
	status_key = status_keys.user.status_too_many_retransmissions,
	alert_severity = alert_consts.alert_severities.error,
	alert_type = alert_consts.alert_types.alert_retransmissions,
	i18n_title = "Too many Retransmissions",
	i18n_title = "The number of packet retransmitted in the flow has surpassed the given threeshold",
}
