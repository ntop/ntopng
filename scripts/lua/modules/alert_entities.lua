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
   }, host = {
      entity_id = 1,
      label = "Host",
      pools = "host_pools", -- modules/pools/host_pools.lua
   }, network = {
      entity_id = 2,
      label = "Network",
      pools = "local_network_pools", -- modules/pools/local_network_pools.lua
   }, snmp_device = {
      entity_id = 3,
      label = "SNMP device",
      pools = "snmp_device_pools", -- modules/pools/snmp_device_pools.lua
   }, flow = {
      entity_id = 4,
      label = "Flow",
      pools = "flow_pools", -- modules/pools/flow_pools.lua
   }, mac = {
      entity_id = 5,
      label = "Device",
      pools = "mac_pools", -- modules/pools/mac_pools.lua
   }, host_pool = {
      entity_id = 6,
      label = "Host Pool",
      pools = "host_pool_pools", -- modules/pools/host_pool_pools.lua
   }, process = {
      entity_id = 7,
      label = "Process",
      pools = "system_pools", -- modules/pools/system_pools.lua
   }, user = {
      entity_id = 8,
      label = "User",
      pools = "system_pools", -- modules/pools/system_pools.lua
   }, influx_db = {
      entity_id = 9,
      label = "Influx DB",
      pools = "system_pools", -- modules/pools/system_pools.lua
   }, test = {
      entity_id = 10,
      label = "Test",
      pools = "system_pools", -- modules/pools/system_pools.lua
   }, category_lists = {
      entity_id = 11,
      label = "Category Lists",
      pools = "system_pools", -- modules/pools/system_pools.lua
   }, am_host = {
      entity_id = 12,
      label = "Active Monitoring Host",
      pools = "active_monitoring_pools", -- modules/pools/active_monitoring_pools.lua
   }, periodic_activity = {
      entity_id = 13,
      label = "Periodic Activity",
      pools = "system_pools", -- modules/pools/system_pools.lua
   }, other = {
      entity_id = 99,
      label = "Other",
      pools = nil, -- no pool for other
   }
}

-- ##############################################

return alert_entities
