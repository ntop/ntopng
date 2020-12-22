--
-- (C) 2019 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param alert_subtype A string indicating the subtype for this alert, one of 'arc_added', 'arc_removed'
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param node1 A string with the name of the first of the two peers involved in the change
-- @param ip1 A string with the ip of the first of the two peers involved in the change
-- @param node2 A string with the name of the second of the two peers involved in the change
-- @param ip2 A string with the ip of the second of the two peers involved in the change
-- @return A table with the alert built
local function createTopologyChanged(alert_severity, alert_subtype, alert_granularity, node1, ip1, node2, ip2)
   local built = {
      alert_subtype = alert_subtype,
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_type_params = {
	 node1 = node1, ip1 = ip1,
	 node2 = node2, ip2 = ip2,
      },
   }

   return built
end

-- #######################################################

local function formatTopologyChanged(ifid, alert, alert_info)
  if not ntop.isPro() then
    return ""
  end

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
  creator = createTopologyChanged,
}
