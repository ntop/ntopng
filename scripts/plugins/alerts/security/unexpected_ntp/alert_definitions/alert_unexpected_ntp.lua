local alert_keys = require "alert_keys"

-- #################################################

local function createUnexpectedNTP(alert_severity, ntp_info)
    local built = {
        alert_severity= alert_severity,
        alert_type_params = ntp_info 
    }

    return built
end

-- #################################################

return {
    alert_key = alert_keys.ntopng.alert_unexpected_ntp_server,
    i18n_title = "unexpected_ntp.alert_unexpected_ntp_title",
    icon = "fas fa-exclamation",
    creator = createUnexpectedNTP,
}
