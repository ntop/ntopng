--
-- (C) 2019 - ntop.org
--

local alert_keys = require "alert_keys"

local function formatTopologyChanged(ifid, alert, alert_info)
  if not ntop.isPro() then
    return ""
  end

  require("snmp_utils")

  if(alert.alert_subtype == "arc_added") then
    return(i18n("alert_messages.lldp_arc_added", {
      node1 = alert_info.node1,
      node2 = alert_info.node2,
      url1 = snmpDeviceUrl(alert_info.ip1),
      url2 = snmpDeviceUrl(alert_info.ip2),
    }))
  else
    return(i18n("alert_messages.lldp_arc_removed", {
      node1 = alert_info.node1,
      node2 = alert_info.node2,
      url1 = snmpDeviceUrl(alert_info.ip1),
      url2 = snmpDeviceUrl(alert_info.ip2),
    }))
  end
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_snmp_topology_changed,
  i18n_title = i18n("snmp.lldp_topology_changed"),
  i18n_description = formatTopologyChanged,
  icon = "fas fa-topology-alt",
}
