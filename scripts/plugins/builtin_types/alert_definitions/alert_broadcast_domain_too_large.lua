--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function formatBroadcastDomainAlert(ifid, alert, info)
  return(i18n("alert_messages.broadcast_domain_too_large", {
    src_mac = info.src_mac,
    src_mac_url = getMacUrl(info.src_mac),
    dst_mac = info.dst_mac,
    dst_mac_url = getMacUrl(info.dst_mac),
    spa = info.spa,
    spa_url = getHostUrl(info.spa, info.vlan_id),
    tpa = info.tpa,
    tpa_url = getHostUrl(info.tpa, info.vlan_id),
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_broadcast_domain_too_large,
  i18n_title = "alerts_dashboard.broadcast_domain_too_large",
  i18n_description = formatBroadcastDomainAlert,
  icon = "fas fa-sitemap",
}
