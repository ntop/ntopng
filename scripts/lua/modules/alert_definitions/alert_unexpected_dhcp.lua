local alert_keys = require "alert_keys"

-- #################################################

local function createUnexpectedDHCP(alert_severity, dhcp_info)
    local built = {
        alert_severity= alert_severity,
        alert_type_params = dhcp_info 
    }

    return built
end

-- #################################################

return {
    alert_key = alert_keys.ntopng.alert_unexpected_dhcp_server,
    i18n_title = "unexpected_dhcp.alert_unexpected_dhcp_title",
    icon = "fas fa-exclamation",
    creator = createUnexpectedDHCP,
}
