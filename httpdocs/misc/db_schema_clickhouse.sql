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
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `FLOW_ID` UInt64
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `CLIENT_NW_LATENCY_US` UInt32
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SERVER_NW_LATENCY_US` UInt32
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `CLIENT_LOCATION` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SERVER_LOCATION` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC_NETWORK_ID` UInt16
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST_NETWORK_ID` UInt16
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `INPUT_SNMP` UInt32
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `OUTPUT_SNMP` UInt32
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC_HOST_POOL_ID` UInt16
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST_HOST_POOL_ID` UInt16
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC_PROC_NAME` String
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST_PROC_NAME` String
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC_PROC_USER_NAME` String
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST_PROC_USER_NAME` String
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `ALERTS_MAP` String
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SEVERITY` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_CLI_ATTACKER` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_CLI_VICTIM` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_CLI_BLACKLISTED` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_SRV_ATTACKER` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_SRV_VICTIM` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_SRV_BLACKLISTED` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `ALERT_STATUS` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `USER_LABEL` String
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `USER_LABEL_TSTAMP` DateTime 
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `ALERT_JSON` String
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `IS_ALERT_DELETED` UInt8
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC2DST_PACKETS` UInt32
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST2SRC_PACKETS` UInt32

@

DROP VIEW IF EXISTS `flow_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `flow_alerts_view` AS SELECT
FLOW_ID AS rowid,
IP_PROTOCOL_VERSION AS ip_version,
FIRST_SEEN AS tstamp,
FIRST_SEEN AS first_seen,
LAST_SEEN AS tstamp_end,
VLAN_ID AS vlan_id,
SRC2DST_PACKETS AS cli2srv_pkts,
DST2SRC_PACKETS AS srv2cli_pkts,
SRC2DST_BYTES AS cli2srv_bytes,
DST2SRC_BYTES AS srv2cli_bytes,
PROTOCOL AS proto,
IF(IPV4_SRC_ADDR != 0, IPv4NumToString(IPV4_SRC_ADDR), IPv6NumToString(IPV6_SRC_ADDR)) AS cli_ip,
IF(IPV4_DST_ADDR != 0, IPv4NumToString(IPV4_DST_ADDR), IPv6NumToString(IPV6_DST_ADDR)) AS srv_ip,
IP_SRC_PORT AS cli_port,
IP_DST_PORT AS srv_port,
L7_PROTO AS l7_proto,
L7_PROTO_MASTER AS l7_master_proto,
L7_CATEGORY AS l7_cat,
FLOW_RISK AS flow_risk_bitmap,
INTERFACE_ID AS interface_id,
STATUS AS alert_id,
ALERT_STATUS AS alert_status,
USER_LABEL AS user_label,
USER_LABEL_TSTAMP AS user_label_tstamp,
char(bitShiftRight(SRC_COUNTRY_CODE, 8), bitAnd(SRC_COUNTRY_CODE, 0xFF)) AS cli_country,
char(bitShiftRight(DST_COUNTRY_CODE, 8), bitAnd(DST_COUNTRY_CODE, 0xFF)) AS srv_country,
SRC_LABEL AS cli_name,
DST_LABEL AS srv_name,
COMMUNITY_ID AS community_id,
SCORE AS score,
SRC_HOST_POOL_ID AS cli_host_pool_id,
DST_HOST_POOL_ID AS srv_host_pool_id,
SRC_NETWORK_ID AS cli_network,
DST_NETWORK_ID AS srv_network,
SEVERITY AS severity,
ALERT_JSON AS json,
IS_CLI_ATTACKER AS is_cli_attacker,
IS_CLI_VICTIM AS is_cli_victim,
IS_SRV_ATTACKER AS is_srv_attacker,
IS_SRV_VICTIM AS is_srv_victim,
IS_CLI_BLACKLISTED AS cli_blacklisted,
IS_SRV_BLACKLISTED AS srv_blacklisted,
CLIENT_LOCATION AS cli_location,
SERVER_LOCATION AS srv_location,
ALERTS_MAP AS alerts_map,
INFO AS info,
IPv4NumToString(PROBE_IP) AS probe_ip,
INPUT_SNMP AS input_snmp,
OUTPUT_SNMP AS output_snmp
FROM `flows`
WHERE STATUS != 0 AND IS_ALERT_DELETED != 1;

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
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);

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
ALTER TABLE host_alerts ADD COLUMN IF NOT EXISTS `country` String

@

DROP VIEW IF EXISTS `all_alerts`;
@
CREATE VIEW IF NOT EXISTS `all_alerts_view` AS
SELECT 8 entity_id, interface_id, alert_id, alert_status, tstamp, tstamp_end, severity, score FROM `active_monitoring_alerts`
UNION ALL 
SELECT 4 entity_id, INTERFACE_ID AS interface_id, STATUS AS alert_id, 0 AS alert_status, FIRST_SEEN AS tstamp, LAST_SEEN AS tstamp_end, SEVERITY AS severity, SCORE AS score FROM `flows` WHERE STATUS != 0 AND IS_ALERT_DELETED != 1
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
