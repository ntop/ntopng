CREATE TABLE IF NOT EXISTS `flows` (
`FLOW_ID` UInt64,
`IP_PROTOCOL_VERSION` UInt8,
`FIRST_SEEN` DateTime,
`LAST_SEEN` DateTime,
`VLAN_ID` UInt16, /* LowCardinality */
`PACKETS` UInt32,
`TOTAL_BYTES` UInt64,
`SRC2DST_BYTES` UInt64,
`DST2SRC_BYTES` UInt64,
`SRC2DST_DSCP` UInt8,
`DST2SRC_DSCP` UInt8,
`PROTOCOL` UInt8,
`IPV4_SRC_ADDR` UInt32,
`IPV6_SRC_ADDR` IPv6,
`IP_SRC_PORT` UInt16,
`IPV4_DST_ADDR` UInt32,
`IPV6_DST_ADDR` IPv6,
`IP_DST_PORT` UInt16,
`L7_PROTO` UInt16,
`L7_PROTO_MASTER` UInt16,
`L7_CATEGORY` UInt16,
`FLOW_RISK` UInt64,
`INFO` String,
`PROFILE` String,
`NTOPNG_INSTANCE_NAME` String,
`INTERFACE_ID` UInt16,
`STATUS` UInt8,
`SRC_COUNTRY_CODE` UInt16,
`DST_COUNTRY_CODE` UInt16,
`SRC_LABEL` String,
`DST_LABEL` String,
`SRC_MAC` UInt64,
`DST_MAC` UInt64,
`COMMUNITY_ID` String,
`SRC_ASN` UInt32,
`DST_ASN` UInt32,
`PROBE_IP` UInt32, /* EXPORTER_IPV4_ADDRESS */
`OBSERVATION_POINT_ID` UInt16,
`SRC2DST_TCP_FLAGS` UInt8,
`DST2SRC_TCP_FLAGS` UInt8,
`SCORE` UInt16,
`CLIENT_NW_LATENCY_US` UInt32,
`SERVER_NW_LATENCY_US` UInt32,
`CLIENT_LOCATION` UInt8,
`SERVER_LOCATION` UInt8,
`SRC_NETWORK_ID` UInt16,
`DST_NETWORK_ID` UInt16,
`INPUT_SNMP` UInt32,
`OUTPUT_SNMP` UInt32,
`SRC_HOST_POOL_ID` UInt16,
`DST_HOST_POOL_ID` UInt16,
`SRC_PROC_NAME` String,
`DST_PROC_NAME` String,
`SRC_PROC_USER_NAME` String,
`DST_PROC_USER_NAME` String
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(FIRST_SEEN) ORDER BY (IPV4_SRC_ADDR, IPV4_DST_ADDR, FIRST_SEEN);
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `FLOW_ID` UInt64;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `CLIENT_NW_LATENCY_US` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SERVER_NW_LATENCY_US` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `CLIENT_LOCATION` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SERVER_LOCATION` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC_NETWORK_ID` UInt16;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST_NETWORK_ID` UInt16;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `INPUT_SNMP` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `OUTPUT_SNMP` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC_HOST_POOL_ID` UInt16;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST_HOST_POOL_ID` UInt16;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC_PROC_NAME` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST_PROC_NAME` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC_PROC_USER_NAME` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST_PROC_USER_NAME` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `ALERTS_MAP` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SEVERITY` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_CLI_ATTACKER` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_CLI_VICTIM` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_CLI_BLACKLISTED` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_SRV_ATTACKER` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_SRV_VICTIM` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_SRV_BLACKLISTED` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `ALERT_STATUS` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `USER_LABEL` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `USER_LABEL_TSTAMP` DateTime;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `ALERT_JSON` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_ALERT_DELETED` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC2DST_PACKETS` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST2SRC_PACKETS` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `ALERT_CATEGORY` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `MINOR_CONNECTION_STATE` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `MAJOR_CONNECTION_STATE` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `PRE_NAT_IPV4_SRC_ADDR` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `PRE_NAT_SRC_PORT` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `PRE_NAT_IPV4_DST_ADDR` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `PRE_NAT_DST_PORT` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `POST_NAT_IPV4_SRC_ADDR` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `POST_NAT_SRC_PORT` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `POST_NAT_IPV4_DST_ADDR` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `POST_NAT_DST_PORT` UInt32;

@

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
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `active_monitoring_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;

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
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(first_seen) ORDER BY (first_seen);
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS cli_host_pool_id UInt16;
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS srv_host_pool_id UInt16;
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS cli_network UInt16;
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS srv_network UInt16;
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS info String;
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS cli_location UInt8;
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS srv_location UInt8;
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS probe_ip String;
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS input_snmp UInt32;
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS output_snmp UInt32;
@
ALTER TABLE `flow_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;

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
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `host_alerts` ADD COLUMN IF NOT EXISTS host_pool_id UInt16;
@
ALTER TABLE `host_alerts` ADD COLUMN IF NOT EXISTS network UInt16;
@
ALTER TABLE `host_alerts` ADD COLUMN IF NOT EXISTS `country` String;
@
ALTER TABLE `host_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;

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
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `mac_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;

@

CREATE TABLE IF NOT EXISTS `snmp_alerts` (
`rowid` UUID,
`alert_id` UInt32 NOT NULL,
`alert_status` UInt8 NOT NULL,
`interface_id` UInt16 NULL,
`ip` String NOT NULL,
`port` UInt32,
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
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `snmp_alerts` MODIFY COLUMN `port` UInt32;
@
ALTER TABLE `snmp_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;

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
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `network_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;

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
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `interface_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;

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
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `user_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;

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
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `system_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;

@
DROP VIEW IF EXISTS `all_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `all_alerts_view` AS
SELECT 8 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score, alert_category FROM `active_monitoring_alerts`
UNION ALL
SELECT 4 entity_id, INTERFACE_ID AS interface_id, STATUS AS alert_id, ALERT_STATUS AS alert_status, FIRST_SEEN AS tstamp, LAST_SEEN AS tstamp_end, SEVERITY AS severity, SCORE AS score, ALERT_CATEGORY AS alert_category FROM `flows` WHERE (STATUS != 0 AND IS_ALERT_DELETED != 1)
UNION ALL
SELECT 1 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score, alert_category FROM `host_alerts`
UNION ALL
SELECT 5 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score, alert_category FROM `mac_alerts`
UNION ALL
SELECT 3 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score, alert_category FROM `snmp_alerts`
UNION ALL
SELECT 2 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score, alert_category FROM `network_alerts`
UNION ALL
SELECT 0 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score, alert_category FROM `interface_alerts`
UNION ALL
SELECT 7 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score, alert_category FROM `user_alerts`
UNION ALL
SELECT 9 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score, alert_category FROM `system_alerts`
;

@

CREATE TABLE IF NOT EXISTS `l7_protocols` (
  `id` UInt16 NOT NULL,
  `name` String NOT NULL
) ENGINE = ReplacingMergeTree() ORDER BY (id);

@

CREATE TABLE IF NOT EXISTS `l7_categories` (
  `id` UInt16 NOT NULL,
  `name` String NOT NULL
) ENGINE = ReplacingMergeTree() ORDER BY (id);

@

CREATE TABLE IF NOT EXISTS `l4_protocols` (
  `id` UInt16 NOT NULL,
  `name` String NOT NULL
) ENGINE = ReplacingMergeTree() ORDER BY (id);

@

CREATE TABLE IF NOT EXISTS `flow_risks` (
  `id` UInt16 NOT NULL,
  `name` String NOT NULL
) ENGINE = ReplacingMergeTree() ORDER BY (id);

@

CREATE TABLE IF NOT EXISTS `alert_severities` (
  `id` UInt16 NOT NULL,
  `name` String NOT NULL
) ENGINE = ReplacingMergeTree() ORDER BY (id);

@

/* Remove */
DROP TABLE IF EXISTS `aggregated_flows`;

@

CREATE TABLE IF NOT EXISTS `hourly_flows` (
       `FLOW_ID` UInt64,
       `IP_PROTOCOL_VERSION` UInt8,
       `FIRST_SEEN` DateTime,
       `LAST_SEEN` DateTime,
       `VLAN_ID` UInt16,
       `PACKETS` UInt32,
       `TOTAL_BYTES` UInt64,
       `SRC2DST_BYTES` UInt64, /* Total */
       `DST2SRC_BYTES` UInt64, /* Total */
       `SCORE` UInt16, /* Total score */
       `PROTOCOL` UInt8,
       `IPV4_SRC_ADDR` UInt32,
       `IPV6_SRC_ADDR` IPv6,
       `IPV4_DST_ADDR` UInt32,
       `IPV6_DST_ADDR` IPv6,
       `IP_DST_PORT` UInt16,
       `L7_PROTO` UInt16,
       `L7_PROTO_MASTER` UInt16,
       `NUM_FLOWS` UInt32, /* Total number of flows that have been aggregated */
       `FLOW_RISK` UInt64, /* OS of flow risk */
       `SRC_MAC` UInt64,
       `DST_MAC` UInt64,
       `PROBE_IP` UInt32, /* EXPORTER_IPV4_ADDRESS */
       `NTOPNG_INSTANCE_NAME` String,
       `SRC_COUNTRY_CODE` UInt16,
       `DST_COUNTRY_CODE` UInt16,
       `SRC_ASN` UInt32,
       `DST_ASN` UInt32,
       `INPUT_SNMP` UInt32,
       `OUTPUT_SNMP` UInt32,
       `SRC_NETWORK_ID` UInt16,
       `DST_NETWORK_ID` UInt16
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(FIRST_SEEN) ORDER BY (IPV4_SRC_ADDR, IPV4_DST_ADDR, FIRST_SEEN);
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS SRC_LABEL String;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS DST_LABEL String;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS INTERFACE_ID UInt16;

@
CREATE TABLE IF NOT EXISTS `vulnerability_scan_data` (
  `HOST` String NOT NULL,
  `SCAN_TYPE` String NOT NULL,
  `LAST_SCAN` DateTime NOT NULL,
  `JSON_INFO` String,
  `VS_RESULT_FILE` String
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(LAST_SCAN) ORDER BY (LAST_SCAN, HOST, SCAN_TYPE);

@
CREATE TABLE IF NOT EXISTS `vulnerability_scan_report` (
  `REPORT_NAME` String,
  `REPORT_DATE` DateTime NOT NULL,
  `REPORT_JSON_INFO` String,
  `NUM_SCANNED_HOSTS` UInt32,
  `NUM_CVES` UInt32,
  `NUM_TCP_PORTS` UInt32,
  `NUM_UDP_PORTS` UInt32
) ENGINE =  MergeTree() PARTITION BY toYYYYMMDD(REPORT_DATE) ORDER BY (REPORT_DATE);


/* MITRE TABLES AND ALERTS VIEWS */

@
CREATE TABLE IF NOT EXISTS `mitre_table_info` (
  `ALERT_ID` UInt16 NOT NULL,
  `ENTITY_ID` UInt16 NOT NULL,
  `TACTIC` UInt16,
  `TECHNIQUE` UInt16,
  `SUB_TECHNIQUE` UInt16,
  `MITRE_ID` String
) ENGINE = ReplacingMergeTree() PRIMARY KEY (ALERT_ID, ENTITY_ID) ORDER BY (ALERT_ID, ENTITY_ID);

@

DROP VIEW IF EXISTS `host_alerts_view`;

@

CREATE VIEW IF NOT EXISTS `host_alerts_view` AS
SELECT
  ha.rowid,
  ha.alert_id,
  ha.alert_status,
  ha.interface_id,
  ha.ip_version,
  ha.ip,
  ha.vlan_id,
  ha.name,
  ha.is_attacker,
  ha.is_victim,
  ha.is_client,
  ha.is_server,
  ha.tstamp,
  ha.tstamp_end,
  ha.severity,
  ha.score,
  ha.granularity,
  ha.counter,
  ha.description,
  ha.json,
  ha.user_label,
  ha.user_label_tstamp,
  mitre.TACTIC AS mitre_tactic,
  mitre.TECHNIQUE AS mitre_technique,
  mitre.SUB_TECHNIQUE AS mitre_subtechnique,
  mitre.MITRE_ID AS mitre_id
FROM
  `host_alerts` AS ha
LEFT JOIN
  `mitre_table_info` AS mitre
ON
  (mitre.ENTITY_ID = 1 AND ha.alert_id = mitre.ALERT_ID);

@

DROP VIEW IF EXISTS `flow_alerts_view`;

@

CREATE VIEW IF NOT EXISTS `flow_alerts_view` AS SELECT
    f.FLOW_ID AS rowid,
    f.IP_PROTOCOL_VERSION AS ip_version,
    f.FIRST_SEEN AS tstamp,
    f.FIRST_SEEN AS first_seen,
    f.LAST_SEEN AS tstamp_end,
    f.VLAN_ID AS vlan_id,
    f.SRC2DST_PACKETS AS cli2srv_pkts,
    f.DST2SRC_PACKETS AS srv2cli_pkts,
    f.SRC2DST_BYTES AS cli2srv_bytes,
    f.DST2SRC_BYTES AS srv2cli_bytes,
    f.PROTOCOL AS proto,
    IF(f.IPV4_SRC_ADDR != 0, IPv4NumToString(f.IPV4_SRC_ADDR), IPv6NumToString(f.IPV6_SRC_ADDR)) AS cli_ip,
    IF(f.IPV4_DST_ADDR != 0, IPv4NumToString(f.IPV4_DST_ADDR), IPv6NumToString(f.IPV6_DST_ADDR)) AS srv_ip,
    f.IP_SRC_PORT AS cli_port,
    f.IP_DST_PORT AS srv_port,
    f.L7_PROTO AS l7_proto,
    f.L7_PROTO_MASTER AS l7_master_proto,
    f.L7_CATEGORY AS l7_cat,
    f.FLOW_RISK AS flow_risk_bitmap,
    f.INTERFACE_ID AS interface_id,
    f.STATUS AS alert_id,
    f.ALERT_STATUS AS alert_status,
    f.USER_LABEL AS user_label,
    f.USER_LABEL_TSTAMP AS user_label_tstamp,
    char(bitShiftRight(f.SRC_COUNTRY_CODE, 8), bitAnd(f.SRC_COUNTRY_CODE, 0xFF)) AS cli_country,
    char(bitShiftRight(f.DST_COUNTRY_CODE, 8), bitAnd(f.DST_COUNTRY_CODE, 0xFF)) AS srv_country,
    f.SRC_LABEL AS cli_name,
    f.DST_LABEL AS srv_name,
    f.COMMUNITY_ID AS community_id,
    f.SCORE AS score,
    f.SRC_HOST_POOL_ID AS cli_host_pool_id,
    f.DST_HOST_POOL_ID AS srv_host_pool_id,
    f.SRC_NETWORK_ID AS cli_network,
    f.DST_NETWORK_ID AS srv_network,
    f.SEVERITY AS severity,
    f.ALERT_JSON AS json,
    f.IS_CLI_ATTACKER AS is_cli_attacker,
    f.IS_CLI_VICTIM AS is_cli_victim,
    f.IS_SRV_ATTACKER AS is_srv_attacker,
    f.IS_SRV_VICTIM AS is_srv_victim,
    f.IS_CLI_BLACKLISTED AS cli_blacklisted,
    f.IS_SRV_BLACKLISTED AS srv_blacklisted,
    f.CLIENT_LOCATION AS cli_location,
    f.SERVER_LOCATION AS srv_location,
    f.ALERTS_MAP AS alerts_map,
    f.INFO AS info,
    IPv4NumToString(f.PROBE_IP) AS probe_ip,
    f.INPUT_SNMP AS input_snmp,
    f.OUTPUT_SNMP AS output_snmp,
    f.ALERT_CATEGORY AS alert_category,
    mitre.TACTIC AS mitre_tactic,
    mitre.TECHNIQUE AS mitre_technique,
    mitre.SUB_TECHNIQUE AS mitre_subtechnique,
    mitre.MITRE_ID AS mitre_id
FROM `flows` AS f
LEFT JOIN `mitre_table_info` AS mitre
    ON (mitre.ENTITY_ID = 4 AND f.STATUS = mitre.ALERT_ID)
WHERE f.STATUS != 0 
    AND f.IS_ALERT_DELETED != 1; 

