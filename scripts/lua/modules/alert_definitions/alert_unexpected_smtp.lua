local alert_keys = require "alert_keys"

-- #################################################

local function createUnexpectedSMTP(alert_severity, smtp_info)
    local built = {
        alert_severity= alert_severity,
        alert_type_params = smtp_info 
    }

    return built
end

-- #################################################

return {
    alert_key = alert_keys.ntopng.alert_unexpected_smtp_server,
    i18n_title = "unexpected_smtp.alert_unexpected_smtp_title",
    icon = "fas fa-exclamation",
    creator = createUnexpectedSMTP,
}
