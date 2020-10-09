local alert_keys = require "alert_keys"

-- #################################################

local function createUnexpectedDNS(alert_severity, dns_info)
    local built = {
        alert_severity= alert_severity,
        alert_type_params = dns_info 
    }

    return built
end

-- #################################################

return {
    alert_key = alert_keys.ntopng.alert_unexpected_dns_server,
    i18n_title = "unexpected_dns.alert_unexpected_dns_title",
    icon = "fas fa-exclamation",
    creator = createUnexpectedDNS,
}
