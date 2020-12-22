local alert_keys = require "alert_keys"

-- #################################################

local function createUnexpectedDNS(client_ip, server_ip)
    local built = {
       alert_type_params = {
	  client_ip = client_ip,
	  server_ip = server_ip
       }
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
