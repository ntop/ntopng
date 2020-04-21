--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

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
}
