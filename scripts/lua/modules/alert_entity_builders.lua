--
-- (C) 2019-24 - ntop.org
--

-- ##############################################
-- entity_info building functions
-- ##############################################

local alert_entities = require "alert_entities"
local alert_entity_builders = {}

function alert_entity_builders.hostAlertEntity(hostip, hostvlan)
   return {
       alert_entity = alert_entities.host,
       -- NOTE: keep in sync with C (Alertable::setEntityValue)
       entity_val = hostinfo2hostkey({
           ip = hostip,
           vlan = hostvlan
       }, nil, true)
   }
end

-- ##############################################

function alert_entity_builders.interfaceAlertEntity(ifid)
   return {
       alert_entity = alert_entities.interface,
       -- NOTE: keep in sync with C (Alertable::setEntityValue)
       entity_val = string.format("%d", ifid)
   }
end

-- ##############################################

function alert_entity_builders.networkAlertEntity(network_cidr)
   return {
       alert_entity = alert_entities.network,
       -- NOTE: keep in sync with C (Alertable::setEntityValue)
       entity_val = network_cidr
   }
end

-- ##############################################

function alert_entity_builders.snmpInterfaceEntity(snmp_device, snmp_interface)
   return {
       alert_entity = alert_entities.snmp_device,
       entity_val = string.format("%s_ifidx%s", snmp_device, "" .. snmp_interface)
   }
end

-- ##############################################

function alert_entity_builders.snmpDeviceEntity(snmp_device)
   return {
       alert_entity = alert_entities.snmp_device,
       entity_val = snmp_device
   }
end

-- ##############################################

function alert_entity_builders.macEntity(mac)
   return {
       alert_entity = alert_entities.mac,
       entity_val = mac
   }
end

-- ##############################################

function alert_entity_builders.userEntity(user)
   return {
       alert_entity = alert_entities.user,
       entity_val = user
   }
end

-- ##############################################

function alert_entity_builders.hostPoolEntity(pool_id)
   return {
       alert_entity = alert_entities.host_pool,
       entity_val = tostring(pool_id)
   }
end

-- ##############################################

function alert_entity_builders.amThresholdCrossEntity(host)
   return {
       alert_entity = alert_entities.am_host,
       entity_val = host
   }
end

-- ##############################################

function alert_entity_builders.systemEntity(system_entity_name)
   return {
       alert_entity = alert_entities.system,
       entity_val = system_entity_name or "system"
   }
end

-- ##############################################

function alert_entity_builders.iec104Entity(flow)
   return {
       alert_entity = alert_entities.flow,
       entity_val = "flow"
   }
end

return alert_entity_builders