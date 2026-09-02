--
-- (C) 2013-26 - ntop.org
--

local json = require("dkjson")

return {
   name = "list_expected_servers",
   description = "Return the IP addresses of all EXPECTED/APPROVED network infrastructure servers configured in ntopng: DNS resolvers, NTP servers, DHCP servers, SMTP mail servers, and default gateways. " ..
      "IMPORTANT: this list defines the LEGITIMATE servers the network administrator expects to see. " ..
      "ntopng monitors all traffic and raises an alert whenever a host communicates with a server of the same type that is NOT in this list. " ..
      "No input parameters needed.",
   handler = function()
      local servers_list = {
         { server_type = "Configured DNS Servers",  list = ntop.getCache("ntopng.prefs.nw_config_dns_list")     or "" },
         { server_type = "Configured NTP Servers",  list = ntop.getCache("ntopng.prefs.nw_config_ntp_list")     or "" },
         { server_type = "Configured DHCP Servers", list = ntop.getCache("ntopng.prefs.nw_config_dhcp_list")    or "" },
         { server_type = "Configured SMTP Servers", list = ntop.getCache("ntopng.prefs.nw_config_smtp_list")    or "" },
         { server_type = "Configured gateway",      list = ntop.getCache("ntopng.prefs.nw_config_gateway_list") or "" },
      }
      return json.encode(servers_list)
   end,
   opts = { read_only = true }
}
