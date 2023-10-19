-- -----------------------------------------------------
-- View that merges all tables together
-- NOTE: integer entity_id MUST BE KEPT IN SYNC WITH IDS in alert_entities.lua
-- -----------------------------------------------------
DROP VIEW IF EXISTS `all_alerts`;
CREATE VIEW IF NOT EXISTS `all_alerts` AS
SELECT 8 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score FROM `active_monitoring_alerts`
UNION ALL 
SELECT 4 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score FROM `flow_alerts`
UNION ALL
SELECT 1 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score FROM `host_alerts`
UNION ALL
SELECT 5 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score FROM `mac_alerts`
UNION ALL
SELECT 3 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score FROM `snmp_alerts`
UNION ALL
SELECT 2 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score FROM `network_alerts`
UNION ALL
SELECT 0 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score FROM `interface_alerts`
UNION ALL
SELECT 7 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score FROM `user_alerts`
UNION ALL
SELECT 9 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score FROM `system_alerts`
;

