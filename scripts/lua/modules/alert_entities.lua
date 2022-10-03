--
-- (C) 2020-22 - ntop.org
--

-- ##############################################

-- Keep in sync with ntop_typedefs.h:AlertEntity and alert_store_schema.sql
local alert_entities = {
   interface = {
      entity_id = 0,
      i18n_label = "alert_entities.interface",
      alert_store_name = "interface",
   }, host = {
      entity_id = 1,
      i18n_label = "alert_entities.host",
      alert_store_name = "host",
   }, network = {
      entity_id = 2,
      i18n_label = "alert_entities.network",
      alert_store_name = "network",
   }, snmp_device = {
      entity_id = 3,
      i18n_label = "alert_entities.snmp_device",
      alert_store_name = "snmp_device",
   }, flow = {
      entity_id = 4,
      i18n_label = "alert_entities.flow",
      alert_store_name = "flow",
   }, mac = {
      entity_id = 5,
      i18n_label = "alert_entities.mac",
      alert_store_name = "mac",
   --}, host_pool = {
   --   entity_id = 6,
   --   i18n_label = "alert_entities.host_pool",
   --   alert_store_name = "system",
   }, user = {
      entity_id = 7,
      i18n_label = "alert_entities.user",
      alert_store_name = "user",
   }, am_host = {
      entity_id = 8,
      i18n_label = "alert_entities.am_host",
      alert_store_name = "am",
   }, system = {
      entity_id = 9,
      i18n_label = "alert_entities.system",
      alert_store_name = "system",
   }, test = { -- Alert on unit test failure (see test_utils.lua)
      entity_id =10,
      i18n_label = "alert_entities.test",
      alert_store_name = "system",
   }, asn = {
      entity_id = 11,
      i18n_label = "alert_entities.asn",
   }, l7 = {
      entity_id = 12,
      i18n_label = "alert_entities.l7",
   }, domain = {
      entity_id = 12,
      i18n_label = "alert_entities.domain",
   }, other = {
      entity_id = 15,
      i18n_label = "alert_entities.other",
      alert_store_name = "system",
   }
}

-- ##############################################

return alert_entities
