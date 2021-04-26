--
-- (C) 2020-21 - ntop.org
--

-- ##############################################

-- Keep in sync with ntop_typedefs.h:AlertEntity
local alert_entities = {
   interface = {
      entity_id = 0,
      label = "Interface",
      pools = "interface_pools", -- modules/pools/interface_pools.lua
      alert_store_name = "interface",
   }, host = {
      entity_id = 1,
      label = "Host",
      pools = "host_pools", -- modules/pools/host_pools.lua
      alert_store_name = "host",
   }, network = {
      entity_id = 2,
      label = "Network",
      pools = "local_network_pools", -- modules/pools/local_network_pools.lua
      alert_store_name = "network",
   }, snmp_device = {
      entity_id = 3,
      label = "SNMP device",
      pools = "snmp_device_pools", -- modules/pools/snmp_device_pools.lua
      alert_store_name = "snmp",
   }, flow = {
      entity_id = 4,
      label = "Flow",
      pools = "flow_pools", -- modules/pools/flow_pools.lua
      alert_store_name = "flow",
   }, mac = {
      entity_id = 5,
      label = "Device",
      pools = "mac_pools", -- modules/pools/mac_pools.lua
      alert_store_name = "mac",
   }, host_pool = {
      entity_id = 6,
      label = "Host Pool",
      pools = "host_pool_pools", -- modules/pools/host_pool_pools.lua
      alert_store_name = "system",
   }, user = {
      entity_id = 7,
      label = "User",
      pools = "system_pools", -- modules/pools/system_pools.lua
      alert_store_name = "user",
   }, am_host = {
      entity_id = 8,
      label = "Active Monitoring Host",
      pools = "active_monitoring_pools", -- modules/pools/active_monitoring_pools.lua
      alert_store_name = "am",
   }, system = {
      entity_id = 9,
      label = "System",
      pools = "system_pools", -- modules/pools/system_pools.lua
      alert_store_name = "system",
   }, test = {
      entity_id =10,
      label = "Test",
      pools = "system_pools", -- modules/pools/system_pools.lua
      alert_store_name = "system",
   }, other = {
      entity_id = 15,
      label = "Other",
      pools = nil, -- no pool for other
      alert_store_name = "system",
   }
}

-- ##############################################

return alert_entities
