local alert_keys = require "alert_keys"

-- ##############################################


local function createRetransmissions(alert_severity, retry_info)
	local built = {
		alert_serverity = alert_severity,
		alert_type_params = retry_info
	}

	return built
end

-- ##############################################



return {
	alert_key = alert_keys.user.alert_user_02,
	i18n_title = "Retransmissions alert",
	icon = "fas fa-exclamation",
	creator = createRetransmissions,
}
