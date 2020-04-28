--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param src_mac A string with the source MAC
-- @param dst_mac A string with the destination MAC
-- @param vlan The VLAN id or zero
-- @param spa The source protocol address (usually the ip address) as a string
-- @param tpa The target protocol address (usually the ip address) as a string
-- @return A table with the alert built
local function createBroadcastDomainTooLargeType(alert_severity, src_mac, dst_mac, vlan, spa, tpa)
  local built = {
    -- Subtype is the concatenation of src and dst macs and ips and the VLAN. This
    -- allows the elerts engine to properly aggregate alerts when they have the same type and subtype
    alert_subtype = string.format("%u_%s_%s_%s_%s", vlan, src_mac, spa, dst_mac, tpa),
    alert_severity = alert_severity,
    alert_type_params = {
      src_mac = src_mac, dst_mac = dst_mac,
      spa = spa, tpa = tpa, vlan_id = vlan,
    },
  }

  return built
end

-- #######################################################

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
  }) .. " <i class=\"fa fa-sm fa-info-circle\" title=\"".. i18n("alert_messages.broadcast_domain_info") .."\"></i>")
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_broadcast_domain_too_large,
  i18n_title = "alerts_dashboard.broadcast_domain_too_large",
  i18n_description = formatBroadcastDomainAlert,
  icon = "fas fa-sitemap",
  creator = createBroadcastDomainTooLargeType,
}
