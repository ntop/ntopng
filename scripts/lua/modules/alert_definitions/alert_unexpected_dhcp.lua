local alert_keys = require "alert_keys"

-- #################################################

local function createUnexpectedDHCP(client_ip, server_ip)
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
    alert_key = alert_keys.ntopng.alert_unexpected_dhcp_server,
    i18n_title = "unexpected_dhcp.alert_unexpected_dhcp_title",
    icon = "fas fa-exclamation",
    creator = createUnexpectedDHCP,
}
