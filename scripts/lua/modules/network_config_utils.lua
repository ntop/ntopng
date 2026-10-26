--
-- (C) 2026 - ntop.org
--

-- The server types of Admin > Network Configuration (expected servers): the
-- REST APIs rest/v2/get|set/network/config.lua and the page are built on this
-- list. To add a server type: add it here, add its key to http_lint.lua (as
-- dns_list) and its i18n title/description in the locales.
-- The core (ServerConfiguration.cpp) reads "ntopng.prefs.nw_config_<name>_list"
-- for its services (dhcp, dns, ntp, smtp, ssh, gateway); the traffic model
-- reads the same Redis keys (pro/scripts/lua/modules/server_types.lua).

local network_config_utils = {}

-- key: POST/GET field; redis_key: comma separated IP[@VLAN] list
network_config_utils.servers = {
   { key = "dns_list", redis_key = "ntopng.prefs.nw_config_dns_list",
     i18n_title = "network_configuration.dns_servers_title", i18n_description = "network_configuration.dns_servers_description" },
   { key = "ntp_list", redis_key = "ntopng.prefs.nw_config_ntp_list",
     i18n_title = "network_configuration.ntp_servers_title", i18n_description = "network_configuration.ntp_servers_description" },
   { key = "dhcp_list", redis_key = "ntopng.prefs.nw_config_dhcp_list",
     i18n_title = "network_configuration.dhcp_servers_title", i18n_description = "network_configuration.dhcp_servers_description" },
   { key = "smtp_list", redis_key = "ntopng.prefs.nw_config_smtp_list",
     i18n_title = "network_configuration.smtp_servers_title", i18n_description = "network_configuration.smtp_servers_description" },
   { key = "ftp_list", redis_key = "ntopng.prefs.nw_config_ftp_list",
     i18n_title = "network_configuration.ftp_servers_title", i18n_description = "network_configuration.ftp_servers_description" },
   -- Legacy Redis key without the _list suffix
   { key = "windows_domain_controller_list", redis_key = "ntopng.prefs.nw_config_windows_domain_controller",
     i18n_title = "network_configuration.windows_domain_controllers_title", i18n_description = "network_configuration.windows_domain_controllers_description" },
   { key = "ssh_list", redis_key = "ntopng.prefs.nw_config_ssh_list",
     i18n_title = "network_configuration.ssh_servers_title", i18n_description = "network_configuration.ssh_servers_description" },
   { key = "powershell_list", redis_key = "ntopng.prefs.nw_config_powershell_list",
     i18n_title = "network_configuration.powershell_servers_title", i18n_description = "network_configuration.powershell_servers_description" },
   { key = "gateway_list", redis_key = "ntopng.prefs.nw_config_gateway_list",
     i18n_title = "network_configuration.gateway_servers_title", i18n_description = "network_configuration.gateway_servers_description" },
}

return network_config_utils
