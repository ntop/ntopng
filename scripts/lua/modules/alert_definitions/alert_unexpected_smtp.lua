local alert_keys = require "alert_keys"

-- #################################################

local function createUnexpectedSMTP(smtp_info)
    local built = {
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
