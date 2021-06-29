--
-- (C) 2020-21 - ntop.org
--

-- ##############################################

-- Keep in sync with ntop_typedefs.h:AlertEntity and alert_store_schema.sql
local alert_entities = {
   interface = {
      entity_id = 0,
      i18n_label = "alert_entities.interface",
      pools = "interface_pools", -- modules/pools/interface_pools.lua
      alert_store_name = "interface",
   }, host = {
      entity_id = 1,
      i18n_label = "alert_entities.host",
      pools = "host_pools", -- modules/pools/host_pools.lua
      alert_store_name = "host",
   }, network = {
      entity_id = 2,
      i18n_label = "alert_entities.network",
      pools = "local_network_pools", -- modules/pools/local_network_pools.lua
      alert_store_name = "network",
   }, snmp_device = {
      entity_id = 3,
      i18n_label = "alert_entities.snmp_device",
      pools = "snmp_device_pools", -- modules/pools/snmp_device_pools.lua
      alert_store_name = "snmp_device",
   }, flow = {
      entity_id = 4,
      i18n_label = "alert_entities.flow",
      pools = "flow_pools", -- modules/pools/flow_pools.lua
      alert_store_name = "flow",
   }, mac = {
      entity_id = 5,
      i18n_label = "alert_entities.mac",
      pools = "mac_pools", -- modules/pools/mac_pools.lua
      alert_store_name = "mac",
   }, host_pool = {
      entity_id = 6,
      i18n_label = "alert_entities.host_pool",
      pools = "host_pool_pools", -- modules/pools/host_pool_pools.lua
      alert_store_name = "system",
   }, user = {
      entity_id = 7,
      i18n_label = "alert_entities.user",
      pools = "system_pools", -- modules/pools/system_pools.lua
      alert_store_name = "user",
   }, am_host = {
      entity_id = 8,
      i18n_label = "alert_entities.am_host",
      pools = "active_monitoring_pools", -- modules/pools/active_monitoring_pools.lua
      alert_store_name = "am",
   }, system = {
      entity_id = 9,
      i18n_label = "alert_entities.system",
      pools = "system_pools", -- modules/pools/system_pools.lua
      alert_store_name = "system",
   }, test = {
      entity_id =10,
      i18n_label = "alert_entities.test",
      pools = "system_pools", -- modules/pools/system_pools.lua
      alert_store_name = "system",
   }, asn = {
      entity_id = 11,
      i18n_label = "alert_entities.asn",
      pools = nil, -- no pool for other
   }, l7 = {
      entity_id = 12,
      i18n_label = "alert_entities.l7",
      pools = nil, -- no pool for other
   }, other = {
      entity_id = 15,
      i18n_label = "alert_entities.other",
      pools = nil, -- no pool for other
      alert_store_name = "system",
   }
}

-- ##############################################

return alert_entities
