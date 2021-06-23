--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_snmp_topology_changed = classes.class(alert)

-- ##############################################

alert_snmp_topology_changed.meta = {  
  alert_key = other_alert_keys.alert_snmp_topology_changed,
  i18n_title = i18n("snmp.lldp_topology_changed"),
  icon = "fas fa-fw fa-topology-alt",
  entities = {
    alert_entities.snmp_device
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param node1 A string with the name of the first of the two peers involved in the change
-- @param ip1 A string with the ip of the first of the two peers involved in the change
-- @param node2 A string with the name of the second of the two peers involved in the change
-- @param ip2 A string with the ip of the second of the two peers involved in the change
-- @return A table with the alert built
function alert_snmp_topology_changed:init(node1, ip1, node2, ip2)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    node1 = node1, ip1 = ip1,
    node2 = node2, ip2 = ip2,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_snmp_topology_changed.format(ifid, alert, alert_type_params)
  if not ntop.isPro() then
    return ""
  end

  if(alert.alert_subtype == "arc_added") then
    return(i18n("alert_messages.lldp_arc_added", {
      node1 = alert_type_params.node1,
      node2 = alert_type_params.node2,
      url1 = snmpDeviceUrl(alert_type_params.ip1),
      url2 = snmpDeviceUrl(alert_type_params.ip2),
    }))
  else
    return(i18n("alert_messages.lldp_arc_removed", {
      node1 = alert_type_params.node1,
      node2 = alert_type_params.node2,
      url1 = snmpDeviceUrl(alert_type_params.ip1),
      url2 = snmpDeviceUrl(alert_type_params.ip2),
    }))
  end
end

-- #######################################################

return alert_snmp_topology_changed
