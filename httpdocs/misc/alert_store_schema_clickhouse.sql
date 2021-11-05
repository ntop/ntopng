CREATE TABLE IF NOT EXISTS `active_monitoring_alerts` (
`rowid` UUID,
`alert_id` UInt32 NOT NULL,
`alert_status` UInt8 NOT NULL,
`interface_id` UInt16 NULL,
`resolved_ip` String,
`resolved_name` String,
`measurement` String,
`measure_threshold` UInt32 NULL,
`measure_value` REAL NULL,
`tstamp` DateTime NOT NULL,
`tstamp_end` DateTime NULL,
`severity` UInt8 NOT NULL,
`score` UInt16 NOT NULL,
`counter` UInt32 NOT NULL,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime NULL 
) ENGINE = MergeTree PARTITION BY toYYYYMM(tstamp) ORDER BY (tstamp);

@

CREATE TABLE IF NOT EXISTS `flow_alerts` (
`rowid` UUID,
`alert_id` UInt32 NOT NULL,
`alert_status` UInt8 NOT NULL,
`interface_id` UInt16 NULL,
`tstamp` DateTime NOT NULL,
`tstamp_end` DateTime,
`severity` UInt8 NOT NULL,
`score` UInt16 NOT NULL,
`counter` UInt32 NOT NULL,
`json` String,
`ip_version` UInt8 NOT NULL,
`cli_ip` String NOT NULL,
`srv_ip` String NOT NULL,
`cli_port` UInt16 NOT NULL,
`srv_port` UInt16 NOT NULL,
`vlan_id` UInt16 NOT NULL,
`is_cli_attacker` UInt8 NOT NULL,
`is_cli_victim` UInt8 NOT NULL,
`is_srv_attacker` UInt8 NOT NULL,
`is_srv_victim` UInt8 NOT NULL,
`proto` UInt8 NOT NULL,
`l7_proto` UInt16 NOT NULL,
`l7_master_proto` UInt16 NOT NULL,
`l7_cat` UInt16 NOT NULL,
`cli_name` String,
`srv_name` String,
`cli_country` String,
`srv_country` String,
`cli_blacklisted` UInt8 NOT NULL,
`srv_blacklisted` UInt8 NOT NULL,
`cli2srv_bytes` UInt8 NOT NULL,
`srv2cli_bytes` UInt8 NOT NULL,
`cli2srv_pkts` UInt8 NOT NULL,
`srv2cli_pkts` UInt8 NOT NULL,
`first_seen` DateTime NOT NULL,
`community_id` String,
`alerts_map` String, -- An HEX bitmap of all flow statuses
`flow_risk_bitmap` UInt64 NOT NULL,
`user_label` String,
`user_label_tstamp` DateTime 
) ENGINE = MergeTree PARTITION BY toYYYYMM(first_seen) ORDER BY (first_seen);

@

CREATE TABLE IF NOT EXISTS `host_alerts` (
`rowid` UUID,
`alert_id` UInt32 NOT NULL,
`alert_status` UInt8 NOT NULL,
`interface_id` UInt16 NULL,
`ip_version` UInt8 NOT NULL,
`ip` String NOT NULL,
`vlan_id` UInt16,
`name` String,
`is_attacker` UInt8,
`is_victim` UInt8,
`is_client` UInt8,
`is_server` UInt8,
`tstamp` DateTime NOT NULL,
`tstamp_end` DateTime,
`severity` UInt8 NOT NULL,
`score` UInt16 NOT NULL,
`granularity` UInt8 NOT NULL,
`counter` UInt32 NOT NULL,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime 
) ENGINE = MergeTree PARTITION BY toYYYYMM(tstamp) ORDER BY (tstamp);

@

CREATE TABLE IF NOT EXISTS `mac_alerts` (
`rowid` UUID,
`alert_id` UInt32 NOT NULL,
`alert_status` UInt8 NOT NULL,
`interface_id` UInt16 NULL,
`address` String,
`device_type` UInt8 NULL,
`name` String,
`is_attacker` UInt8,
`is_victim` UInt8,
`tstamp` DateTime NOT NULL,
`tstamp_end` DateTime,
`severity` UInt8 NOT NULL,
`score` UInt16 NOT NULL,
`granularity` UInt8 NOT NULL,
`counter` UInt32 NOT NULL,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime 
) ENGINE = MergeTree PARTITION BY toYYYYMM(tstamp) ORDER BY (tstamp);

@

CREATE TABLE IF NOT EXISTS `snmp_alerts` (
`rowid` UUID,
`alert_id` UInt32 NOT NULL,
`alert_status` UInt8 NOT NULL,
`interface_id` UInt16 NULL,
`ip` String NOT NULL,
`port` UInt16,
`name` String,
`port_name` String,
`tstamp` DateTime NOT NULL,
`tstamp_end` DateTime,
`severity` UInt8 NOT NULL,
`score` UInt16 NOT NULL,
`granularity` UInt8 NOT NULL,
`counter` UInt32 NOT NULL,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime 
) ENGINE = MergeTree PARTITION BY toYYYYMM(tstamp) ORDER BY (tstamp);

@

CREATE TABLE IF NOT EXISTS `network_alerts` (
`rowid` UUID,
`local_network_id` UInt16 NOT NULL,
`alert_id` UInt32 NOT NULL,
`alert_status` UInt8 NOT NULL,
`interface_id` UInt16 NULL,	
`name` String,
`alias` String,
`tstamp` DateTime NOT NULL,
`tstamp_end` DateTime,
`severity` UInt8 NOT NULL,
`score` UInt16 NOT NULL,
`granularity` UInt8 NOT NULL,
`counter` UInt32 NOT NULL,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime 
) ENGINE = MergeTree PARTITION BY toYYYYMM(tstamp) ORDER BY (tstamp);

@

CREATE TABLE IF NOT EXISTS `interface_alerts` (
`rowid` UUID,
`ifid` UInt8 NOT NULL,
`alert_id` UInt32 NOT NULL,
`alert_status` UInt8 NOT NULL,
`interface_id` UInt16 NULL,
`subtype` String,
`name` String,
`alias` String,
`tstamp` DateTime NOT NULL,
`tstamp_end` DateTime,
`severity` UInt8 NOT NULL,
`score` UInt16 NOT NULL,
`granularity` UInt8 NOT NULL,
`counter` UInt32 NOT NULL,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime 
) ENGINE = MergeTree PARTITION BY toYYYYMM(tstamp) ORDER BY (tstamp);

@

CREATE TABLE IF NOT EXISTS `user_alerts` (
`rowid` UUID,
`alert_id` UInt32 NOT NULL,
`alert_status` UInt8 NOT NULL,
`interface_id` UInt16 NULL,
`user` String,
`tstamp` DateTime NOT NULL,
`tstamp_end` DateTime,
`severity` UInt8 NOT NULL,
`score` UInt16 NOT NULL,
`granularity` UInt8 NOT NULL,
`counter` UInt32 NOT NULL,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime 
) ENGINE = MergeTree PARTITION BY toYYYYMM(tstamp) ORDER BY (tstamp);

@

CREATE TABLE IF NOT EXISTS `system_alerts` (
`rowid` UUID,
`alert_id` UInt32 NOT NULL,
`alert_status` UInt8 NOT NULL,
`interface_id` UInt16 NULL,
`name` String,
`tstamp` DateTime NOT NULL,
`tstamp_end` DateTime,
`severity` UInt8 NOT NULL,
`score` UInt16 NOT NULL,
`granularity` UInt8 NOT NULL,
`counter` UInt32 NOT NULL,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime 
) ENGINE = MergeTree PARTITION BY toYYYYMM(tstamp) ORDER BY (tstamp);

@

DROP VIEW IF EXISTS `all_alerts`;

@

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
