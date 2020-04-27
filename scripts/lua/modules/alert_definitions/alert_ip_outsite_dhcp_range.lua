--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param router_info The host info of the router
-- @param mac The mac address of the device outside the range
-- @param client_mac The client mac as seen in the DHCP packet as string
-- @param sender_mac The sender mac as seen in the DHCP packet as string
-- @return A table with the alert built
local function createIpOutsideDHCPRangeType(alert_severity, router_info, mac, client_mac, sender_mac)
  local built = {
     alert_severity = alert_severity,
     alert_subtype = string.format("%s_%s_%s", hostinfo2hostkey(router_info), client_mac, sender_mac),
     alert_type_params = {
	router_info = hostinfo2hostkey(router_info),
	mac = mac,
	client_mac = client_mac,
	sender_mac = sender_mac,
	router_host = host2name(router_info["host"], router_info["vlan"]),
     },
  }

  return built
end

-- #######################################################

local function outsideDhcpRangeFormatter(ifid, alert, info)
  local hostinfo = hostkey2hostinfo(alert.alert_entity_val)
  local hostkey = hostinfo2hostkey(hostinfo)
  local router_info = hostkey2hostinfo(info.router_info)

  return(i18n("alert_messages.ip_outsite_dhcp_range", {
    client_url = getMacUrl(info.client_mac),
    client_mac = get_symbolic_mac(info.client_mac, true),
    client_ip = hostkey,
    client_ip_url = getHostUrl(hostinfo["host"], hostinfo["vlan"]),
    dhcp_url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid="..ifid.."&page=dhcp",
    sender_url = getMacUrl(info.sender_mac),
    sender_mac = get_symbolic_mac(info.sender_mac, true),
  }) .. " " .. ternary(router_info["host"] == "0.0.0.0", "", i18n("alert_messages.ip_outside_dhcp_range_router_ip", {
    router_url = getHostUrl(router_info["host"], router_info["vlan"]),
    router_ip = info.router_host,
  })))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_ip_outsite_dhcp_range,
  i18n_title = "alerts_dashboard.misconfigured_dhcp_range",
  i18n_description = outsideDhcpRangeFormatter,
  icon = "fas fa-exclamation",
  creator = createIpOutsideDHCPRangeType,
}
