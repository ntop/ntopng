--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_ip_outsite_dhcp_range = classes.class(alert)

-- ##############################################

alert_ip_outsite_dhcp_range.meta = {
  alert_key = other_alert_keys.alert_ip_outsite_dhcp_range,
  i18n_title = "alerts_dashboard.misconfigured_dhcp_range",
  icon = "fas fa-fw fa-exclamation",
  entities = {},
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param router_info The host info of the router
-- @param mac The mac address of the device outside the range
-- @param client_mac The client mac as seen in the DHCP packet as string
-- @param sender_mac The sender mac as seen in the DHCP packet as string
-- @return A table with the alert built
function alert_ip_outsite_dhcp_range:init(router_info, mac, client_mac, sender_mac)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    router_info = hostinfo2hostkey(router_info),
    mac = mac,
    client_mac = client_mac,
    sender_mac = sender_mac,
    router_host = hostinfo2label(router_info),
   }
end

-- #######################################################

function alert_ip_outsite_dhcp_range.format(ifid, alert, alert_type_params)
  local hostinfo = hostkey2hostinfo(alert.entity_val)
  local hostkey = hostinfo2hostkey(hostinfo)
  local router_info = hostkey2hostinfo(alert_type_params.router_info)

  return(i18n("alert_messages.ip_outsite_dhcp_range", {
    client_url = getMacUrl(alert_type_params.client_mac),
    client_mac = get_symbolic_mac(alert_type_params.client_mac, true),
    client_ip = hostkey,
    client_ip_url = getHostUrl(hostinfo["host"], hostinfo["vlan"]),
    dhcp_url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid="..ifid.."&page=dhcp",
    sender_url = getMacUrl(alert_type_params.sender_mac),
    sender_mac = get_symbolic_mac(alert_type_params.sender_mac, true),
  }) .. " " .. ternary(router_info["host"] == "0.0.0.0", "", i18n("alert_messages.ip_outside_dhcp_range_router_ip", {
    router_url = getHostUrl(router_info["host"], router_info["vlan"]),
    router_ip = alert_type_params.router_host,
  })))
end

-- #######################################################

return alert_ip_outsite_dhcp_range
