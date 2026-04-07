/* Keep flows columns definition in sync with: */
/* - httpdocs/misc/db_schema_clickhouse_cluster.sql */
/* - pro/include/FlowsTable.h */
/* - pro/src/ClickHouseDB.cpp -> ClickHouseDB::dumpFlow() */
/* - scripts/lua/modules/tag_utils.lua -> By adding the new tags for filters */
/* - scripts/lua/modules/historical_flow_utils.lua -> Columns mapping */
/* - doc/README.clickhouse_schema.md */

CREATE TABLE IF NOT EXISTS `flows` (
`FLOW_ID` UInt64 COMMENT 'Unique flow identifier assigned by ntopng',
`IP_PROTOCOL_VERSION` UInt8 COMMENT 'IP version: 4 for IPv4, 6 for IPv6',
`FIRST_SEEN` DateTime COMMENT 'Timestamp of the first packet of the flow',
`LAST_SEEN` DateTime COMMENT 'Timestamp of the last packet of the flow',
`VLAN_ID` UInt16 /* LowCardinality */ COMMENT '802.1Q VLAN tag (0 if untagged)',
`PACKETS` UInt32 COMMENT 'Total packet count in both directions',
`TOTAL_BYTES` UInt64 COMMENT 'Total bytes transferred in both directions',
`SRC2DST_BYTES` UInt64 COMMENT 'Bytes sent from client (source) to server (destination)',
`DST2SRC_BYTES` UInt64 COMMENT 'Bytes sent from server (destination) to client (source)',
`SRC2DST_DSCP` UInt8 COMMENT 'DSCP value observed in the client-to-server direction',
`DST2SRC_DSCP` UInt8 COMMENT 'DSCP value observed in the server-to-client direction',
`PROTOCOL` UInt8 COMMENT 'IP transport protocol number (6=TCP, 17=UDP, 1=ICMP, etc.)',
`IPV4_SRC_ADDR` UInt32 COMMENT 'Source IPv4 address as a 32-bit integer; 0 for IPv6 flows',
`IPV6_SRC_ADDR` IPv6 COMMENT 'Source IPv6 address; all-zeros for IPv4 flows',
`IP_SRC_PORT` UInt16 COMMENT 'Source (client) port number',
`IPV4_DST_ADDR` UInt32 COMMENT 'Destination IPv4 address as a 32-bit integer; 0 for IPv6 flows',
`IPV6_DST_ADDR` IPv6 COMMENT 'Destination IPv6 address; all-zeros for IPv4 flows',
`IP_DST_PORT` UInt16 COMMENT 'Destination (server) port number',
`L7_PROTO` UInt16 COMMENT 'nDPI layer-7 application protocol identifier',
`L7_PROTO_MASTER` UInt16 COMMENT 'nDPI master/carrier protocol ID (e.g. TLS when L7_PROTO is HTTPS)',
`L7_CATEGORY` UInt16 COMMENT 'nDPI application category identifier',
`FLOW_RISK` UInt64 COMMENT 'Bitmap of nDPI flow risk flags (each bit represents a distinct risk)',
`INFO` String COMMENT 'Supplementary flow info extracted by nDPI (e.g. HTTP host, DNS query name, TLS SNI)',
`PROFILE` String COMMENT 'Traffic policy profile name matched by this flow',
`NTOPNG_INSTANCE_NAME` String COMMENT 'Hostname/name of the ntopng instance that captured this flow',
`INTERFACE_ID` UInt16 COMMENT 'ntopng internal interface identifier',
`STATUS` UInt8 COMMENT 'Flow alert type ID (0 = normal non-alert flow; non-zero = alert type)',
`SRC_COUNTRY_CODE` UInt16 COMMENT 'Source IP geo-country: two ASCII letters packed into a UInt16 (high byte = first letter)',
`DST_COUNTRY_CODE` UInt16 COMMENT 'Destination IP geo-country: two ASCII letters packed into a UInt16 (high byte = first letter)',
`SRC_LABEL` String COMMENT 'Resolved hostname or user-defined label for the source host',
`DST_LABEL` String COMMENT 'Resolved hostname or user-defined label for the destination host',
`SRC_MAC` UInt64 COMMENT 'Source MAC address encoded as a 64-bit integer',
`DST_MAC` UInt64 COMMENT 'Destination MAC address encoded as a 64-bit integer',
`COMMUNITY_ID` String COMMENT 'Community ID v1 flow hash for cross-tool correlation',
`SRC_ASN` UInt32 COMMENT 'Autonomous System Number of the source IP',
`DST_ASN` UInt32 COMMENT 'Autonomous System Number of the destination IP',
`PROBE_IP` UInt32 /* EXPORTER_IPV4_ADDRESS */ COMMENT 'IPv4 address of the NetFlow/IPFIX exporter (probe); same as EXPORTER_IPV4_ADDRESS',
`EXPORTER_SITE` UInt16 COMMENT 'Site/location identifier of the flow exporter',
`INTERFACE_ROLE` UInt8 COMMENT 'Role of the SMMP interface (e.g. peering, transit, internal network interface)',
`OBSERVATION_POINT_ID` UInt16 COMMENT 'IPFIX observation point identifier',
`SRC2DST_TCP_FLAGS` UInt8 COMMENT 'Bitwise OR of TCP flags seen in the client-to-server direction',
`DST2SRC_TCP_FLAGS` UInt8 COMMENT 'Bitwise OR of TCP flags seen in the server-to-client direction',
`SCORE` UInt16 COMMENT 'Composite flow risk/security score',
`QOE_SCORE` UInt8 COMMENT 'Quality of Experience score (0=best)',
`CLIENT_NW_LATENCY_US` UInt32 COMMENT 'Estimated client-side network RTT in microseconds',
`SERVER_NW_LATENCY_US` UInt32 COMMENT 'Estimated server-side network RTT in microseconds',
`CLIENT_LOCATION` UInt8 COMMENT 'Client host location type (local LAN, remote, etc.)',
`SERVER_LOCATION` UInt8 COMMENT 'Server host location type (local LAN, remote, etc.)',
`SRC_NETWORK_ID` UInt32 COMMENT 'ntopng local-network ID for the source IP (0 if not a known local network)',
`DST_NETWORK_ID` UInt32 COMMENT 'ntopng local-network ID for the destination IP (0 if not a known local network)',
`CLIENT_FINGERPRINT` String COMMENT 'TLS/QUIC client fingerprint (JA3 or similar)',
`TCP_FINGERPRINT` String COMMENT 'TCP stack fingerprint used for passive OS detection',
`INPUT_SNMP` UInt32 COMMENT 'SNMP input interface index exported via NetFlow/IPFIX',
`OUTPUT_SNMP` UInt32 COMMENT 'SNMP output interface index exported via NetFlow/IPFIX',
`SRC_HOST_POOL_ID` UInt16 COMMENT 'ntopng host-pool ID of the source host',
`DST_HOST_POOL_ID` UInt16 COMMENT 'ntopng host-pool ID of the destination host',
`SRC_PROC_NAME` String COMMENT 'Name of the OS process that originated the flow (from eBPF/sysdig)',
`DST_PROC_NAME` String COMMENT 'Name of the OS process that received the flow (from eBPF/sysdig)',
`SRC_PROC_USER_NAME` String COMMENT 'OS username owning the source process',
`DST_PROC_USER_NAME` String COMMENT 'OS username owning the destination process',
`ALERTS_MAP` String COMMENT 'Serialized bitmap of individual alert conditions triggered on this flow',
`SEVERITY` UInt8 COMMENT 'Alert severity level; meaningful only when STATUS != 0',
`IS_CLI_ATTACKER` UInt8 COMMENT '1 if the client host is flagged as an attacker, 0 otherwise',
`IS_CLI_VICTIM` UInt8 COMMENT '1 if the client host is flagged as a victim, 0 otherwise',
`IS_CLI_BLACKLISTED` UInt8 COMMENT '1 if the client IP appears on a threat-intel blacklist, 0 otherwise',
`IS_SRV_ATTACKER` UInt8 COMMENT '1 if the server host is flagged as an attacker, 0 otherwise',
`IS_SRV_VICTIM` UInt8 COMMENT '1 if the server host is flagged as a victim, 0 otherwise',
`IS_SRV_BLACKLISTED` UInt8 COMMENT '1 if the server IP appears on a threat-intel blacklist, 0 otherwise',
`ALERT_STATUS` UInt8 COMMENT 'Alert lifecycle status (e.g. acknowledged, in-progress)',
`USER_LABEL` String COMMENT 'User-defined free-text label applied to this flow',
`USER_LABEL_TSTAMP` DateTime COMMENT 'Timestamp when USER_LABEL was last modified',
`PROTOCOL_INFO_JSON` String COMMENT 'Protocol-specific metadata (HTTP URL, DNS answers, TLS cert info, etc.) as JSON',
`ALERT_JSON` String COMMENT 'Alert-specific context and evidence as a JSON blob',
`IS_ALERT_DELETED` UInt8 COMMENT '1 if the alert on this flow was manually acknowledged/deleted, 0 otherwise',
`SRC2DST_PACKETS` UInt32 COMMENT 'Packet count from client (source) to server (destination)',
`DST2SRC_PACKETS` UInt32 COMMENT 'Packet count from server (destination) to client (source)',
`ALERT_CATEGORY` UInt8 COMMENT 'Alert category identifier (maps to ntopng AlertCategory enum)',
`MINOR_CONNECTION_STATE` UInt8 COMMENT 'Fine-grained TCP/flow connection state',
`MAJOR_CONNECTION_STATE` UInt8 COMMENT 'Coarse TCP connection state (e.g. established, closing, closed)',
`POST_NAT_IPV4_SRC_ADDR` UInt32 COMMENT 'Source IPv4 address after NAT translation',
`POST_NAT_SRC_PORT` UInt32 COMMENT 'Source port after NAT translation',
`POST_NAT_IPV4_DST_ADDR` UInt32 COMMENT 'Destination IPv4 address after NAT translation',
`POST_NAT_DST_PORT` UInt32 COMMENT 'Destination port after NAT translation',
`WLAN_SSID` String COMMENT 'Wireless LAN SSID associated with this flow',
`WTP_MAC_ADDRESS` UInt64 COMMENT 'MAC address of the Wireless Termination Point (access point) as a 64-bit integer',
`DOMAIN_NAME` String COMMENT 'Domain name contacted extracted from the flow (from SNI, DNS, or HTTP Host header)',
`SRC_PEER_ASN` UInt32 COMMENT 'BGP peer ASN upstream of the source IP',
`DST_PEER_ASN` UInt32 COMMENT 'BGP peer ASN upstream of the destination IP',
`REQUIRE_ATTENTION` Boolean COMMENT 'True if this flow/alert has been flagged as requiring manual review'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(FIRST_SEEN) ORDER BY (FIRST_SEEN, IPV4_SRC_ADDR, IPV4_DST_ADDR)
COMMENT 'Per-flow telemetry records captured locally or received via NetFlow/sFlow/IPFIX. Each row represents one bidirectional network flow with 5-tuple (src/dst IP, src/dst port, protocol), byte/packet counters, L7 application identification, flow-risk bitmap, DSCP, NAT addresses, process info, and optional alert metadata. Partitioned by day on FIRST_SEEN.';
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
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC_NETWORK_ID` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST_NETWORK_ID` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `CLIENT_FINGERPRINT` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `TCP_FINGERPRINT` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `INPUT_SNMP` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `OUTPUT_SNMP` UInt32;
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
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `PROTOCOL_INFO_JSON` String;
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
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `POST_NAT_IPV4_SRC_ADDR` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `POST_NAT_SRC_PORT` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `POST_NAT_IPV4_DST_ADDR` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `POST_NAT_DST_PORT` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `WLAN_SSID` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `WTP_MAC_ADDRESS` UInt64;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DOMAIN_NAME` String;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `REQUIRE_ATTENTION` Boolean;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `QOE_SCORE` UInt8;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `SRC_PEER_ASN` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `DST_PEER_ASN` UInt32;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `EXPORTER_SITE` UInt16;
@
ALTER TABLE flows ADD COLUMN IF NOT EXISTS `INTERFACE_ROLE` UInt8;
@
ALTER TABLE flows DROP COLUMN IF EXISTS `PRE_NAT_IPV4_SRC_ADDR`;
@
ALTER TABLE flows DROP COLUMN IF EXISTS `PRE_NAT_SRC_PORT`;
@
ALTER TABLE flows DROP COLUMN IF EXISTS `PRE_NAT_IPV4_DST_ADDR`;
@
ALTER TABLE flows DROP COLUMN IF EXISTS `PRE_NAT_DST_PORT`;

@

CREATE TABLE IF NOT EXISTS `active_monitoring_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`resolved_ip` String COMMENT 'IP address resolved from the monitored hostname at time of check',
`resolved_name` String COMMENT 'Hostname or target being monitored (FQDN or IP)',
`measurement` String COMMENT 'Type of active monitoring check (e.g. icmp, http, https, tls)',
`measure_threshold` UInt32 DEFAULT 0 COMMENT 'Configured threshold value that was exceeded to trigger the alert',
`measure_value` REAL DEFAULT 0.0 COMMENT 'Measured value (e.g. latency in ms, HTTP response code) at alert time',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime DEFAULT toDateTime(0) COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime DEFAULT toDateTime(0) COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp)
COMMENT 'Historical alerts generated by the active monitoring subsystem (ICMP ping, HTTP, TLS checks, etc.). Rows are appended when an engaged alert is archived. See engaged_active_monitoring_alerts for currently-firing alerts and active_monitoring_alerts_view to query both together.';
@
ALTER TABLE `active_monitoring_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `active_monitoring_alerts` ADD COLUMN IF NOT EXISTS require_attention Boolean;

@

DROP TABLE IF EXISTS `engaged_active_monitoring_alerts`;
@
CREATE TABLE `engaged_active_monitoring_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`resolved_ip` String COMMENT 'IP address resolved from the monitored hostname at time of check',
`resolved_name` String COMMENT 'Hostname or target being monitored (FQDN or IP)',
`measurement` String COMMENT 'Type of active monitoring check (e.g. icmp, http, https, tls)',
`measure_threshold` UInt32 DEFAULT 0 COMMENT 'Configured threshold value that was exceeded to trigger the alert',
`measure_value` REAL DEFAULT 0.0 COMMENT 'Measured value (e.g. latency in ms, HTTP response code) at alert time',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime DEFAULT toDateTime(0) COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime DEFAULT toDateTime(0) COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = Memory
COMMENT 'In-memory table holding currently active (engaged) active-monitoring alerts. Rows are inserted when an alert fires and removed when resolved. Merged with active_monitoring_alerts in active_monitoring_alerts_view.';

@

CREATE TABLE IF NOT EXISTS `host_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`ip_version` UInt8 COMMENT 'IP version of the host: 4 for IPv4, 6 for IPv6',
`ip` String COMMENT 'IP address of the host that triggered the alert',
`vlan_id` UInt16 COMMENT 'VLAN on which the host was observed (0 if untagged)',
`name` String COMMENT 'Resolved hostname or user-defined name for the host',
`is_attacker` UInt8 COMMENT '1 if the host is the attacking party in this alert',
`is_victim` UInt8 COMMENT '1 if the host is the victim party in this alert',
`is_client` UInt8 COMMENT '1 if the host acted as a client in the triggering flow',
`is_server` UInt8 COMMENT '1 if the host acted as a server in the triggering flow',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`host_pool_id` UInt16 COMMENT 'ntopng host-pool ID the host belongs to',
`network` UInt16 COMMENT 'ntopng local-network ID the host belongs to',
`country` String COMMENT 'Two-letter ISO 3166-1 country code derived from the host IP',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp)
COMMENT 'Historical alerts associated with individual hosts (identified by IP address and VLAN). Rows are appended when an engaged host alert is archived. See engaged_host_alerts for currently-firing alerts and host_alerts_view to query both together (with MITRE ATT&CK enrichment).';
@
ALTER TABLE `host_alerts` ADD COLUMN IF NOT EXISTS `host_pool_id` UInt16;
@
ALTER TABLE `host_alerts` ADD COLUMN IF NOT EXISTS `network` UInt16;
@
ALTER TABLE `host_alerts` ADD COLUMN IF NOT EXISTS `country` String;
@
ALTER TABLE `host_alerts` ADD COLUMN IF NOT EXISTS `alert_category` UInt8;
@
ALTER TABLE `host_alerts` ADD COLUMN IF NOT EXISTS `require_attention` UInt8;

@

DROP TABLE IF EXISTS `engaged_host_alerts`;
@
CREATE TABLE `engaged_host_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`ip_version` UInt8 COMMENT 'IP version of the host: 4 for IPv4, 6 for IPv6',
`ip` String COMMENT 'IP address of the host that triggered the alert',
`vlan_id` UInt16 COMMENT 'VLAN on which the host was observed (0 if untagged)',
`name` String COMMENT 'Resolved hostname or user-defined name for the host',
`is_attacker` UInt8 COMMENT '1 if the host is the attacking party in this alert',
`is_victim` UInt8 COMMENT '1 if the host is the victim party in this alert',
`is_client` UInt8 COMMENT '1 if the host acted as a client in the triggering flow',
`is_server` UInt8 COMMENT '1 if the host acted as a server in the triggering flow',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`host_pool_id` UInt16 COMMENT 'ntopng host-pool ID the host belongs to',
`network` UInt16 COMMENT 'ntopng local-network ID the host belongs to',
`country` String COMMENT 'Two-letter ISO 3166-1 country code derived from the host IP',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = Memory
COMMENT 'In-memory table holding currently active (engaged) host alerts. Rows are inserted when an alert fires and removed when resolved. Merged with host_alerts in host_alerts_view.';

@

CREATE TABLE IF NOT EXISTS `mac_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`address` String COMMENT 'MAC address of the device that triggered the alert (colon-separated hex)',
`device_type` UInt8 DEFAULT 0 COMMENT 'Device category/type identifier (maps to ntopng DeviceType enum)',
`name` String COMMENT 'User-defined or discovered name for the device',
`is_attacker` UInt8 COMMENT '1 if the device is the attacking party in this alert',
`is_victim` UInt8 COMMENT '1 if the device is the victim party in this alert',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp)
COMMENT 'Historical alerts associated with MAC addresses and layer-2 devices. See engaged_mac_alerts for currently-firing alerts and mac_alerts_view to query both together.';
@
ALTER TABLE `mac_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `mac_alerts` ADD COLUMN IF NOT EXISTS require_attention Boolean;

@

DROP TABLE IF EXISTS `engaged_mac_alerts`;
@
CREATE TABLE `engaged_mac_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`address` String COMMENT 'MAC address of the device that triggered the alert (colon-separated hex)',
`device_type` UInt8 DEFAULT 0 COMMENT 'Device category/type identifier (maps to ntopng DeviceType enum)',
`name` String COMMENT 'User-defined or discovered name for the device',
`is_attacker` UInt8 COMMENT '1 if the device is the attacking party in this alert',
`is_victim` UInt8 COMMENT '1 if the device is the victim party in this alert',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = Memory
COMMENT 'In-memory table holding currently active (engaged) MAC/device alerts. Rows are inserted when an alert fires and removed when resolved. Merged with mac_alerts in mac_alerts_view.';

@

CREATE TABLE IF NOT EXISTS `snmp_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`ip` String COMMENT 'IP address of the SNMP-polled device that triggered the alert',
`port` UInt32 COMMENT 'SNMP interface index (ifIndex) of the interface that triggered the alert',
`name` String COMMENT 'SNMP sysName or user-defined name of the device',
`port_name` String COMMENT 'SNMP ifDescr or user-defined name of the triggering interface',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp)
COMMENT 'Historical alerts from SNMP-polled network devices and their individual ports. See engaged_snmp_alerts for currently-firing alerts and snmp_alerts_view to query both together.';
@
ALTER TABLE `snmp_alerts` MODIFY COLUMN `port` UInt32;
@
ALTER TABLE `snmp_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `snmp_alerts` ADD COLUMN IF NOT EXISTS require_attention Boolean;

@

DROP TABLE IF EXISTS `engaged_snmp_alerts`;
@
CREATE TABLE `engaged_snmp_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`ip` String COMMENT 'IP address of the SNMP-polled device that triggered the alert',
`port` UInt32 COMMENT 'SNMP interface index (ifIndex) of the interface that triggered the alert',
`name` String COMMENT 'SNMP sysName or user-defined name of the device',
`port_name` String COMMENT 'SNMP ifDescr or user-defined name of the triggering interface',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = Memory
COMMENT 'In-memory table holding currently active (engaged) SNMP alerts. Rows are inserted when an alert fires and removed when resolved. Merged with snmp_alerts in snmp_alerts_view.';

@

CREATE TABLE IF NOT EXISTS `network_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`local_network_id` UInt16 COMMENT 'ntopng internal identifier of the local network subnet',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`name` String COMMENT 'CIDR notation or user-defined name of the network (e.g. 192.168.1.0/24)',
`alias` String COMMENT 'User-defined alias for the network',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp)
COMMENT 'Historical alerts associated with local network subnets (identified by local_network_id). See engaged_network_alerts for currently-firing alerts and network_alerts_view to query both together.';
@
ALTER TABLE `network_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `network_alerts` ADD COLUMN IF NOT EXISTS require_attention Boolean;

@

DROP TABLE IF EXISTS `engaged_network_alerts`;
@
CREATE TABLE `engaged_network_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`local_network_id` UInt16 COMMENT 'ntopng internal identifier of the local network subnet',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`name` String COMMENT 'CIDR notation or user-defined name of the network (e.g. 192.168.1.0/24)',
`alias` String COMMENT 'User-defined alias for the network',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = Memory
COMMENT 'In-memory table holding currently active (engaged) network/subnet alerts. Rows are inserted when an alert fires and removed when resolved. Merged with network_alerts in network_alerts_view.';

@

CREATE TABLE IF NOT EXISTS `as_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`asn` UInt32 COMMENT 'Autonomous System Number that triggered the alert',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`name` String COMMENT 'AS name/description (from WHOIS or user configuration)',
`alias` String COMMENT 'User-defined alias for this AS',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp)
COMMENT 'Historical alerts associated with Autonomous Systems (identified by ASN). See engaged_as_alerts for currently-firing alerts and as_alerts_view to query both together.';

@

DROP TABLE IF EXISTS `engaged_as_alerts`;
@
CREATE TABLE `engaged_as_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`asn` UInt32 COMMENT 'Autonomous System Number that triggered the alert',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`name` String COMMENT 'AS name/description (from WHOIS or user configuration)',
`alias` String COMMENT 'User-defined alias for this AS',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = Memory
COMMENT 'In-memory table holding currently active (engaged) Autonomous System alerts. Rows are inserted when an alert fires and removed when resolved. Merged with as_alerts in as_alerts_view.';

@

CREATE TABLE IF NOT EXISTS `interface_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`ifid` UInt8 COMMENT 'ntopng internal interface index',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`subtype` String COMMENT 'Alert sub-type string providing additional context',
`name` String COMMENT 'Interface name (e.g. eth0, wlan0)',
`alias` String COMMENT 'User-defined alias for the interface',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp)
COMMENT 'Historical alerts associated with monitored network interfaces. See engaged_interface_alerts for currently-firing alerts and interface_alerts_view to query both together.';
@
ALTER TABLE `interface_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `interface_alerts` ADD COLUMN IF NOT EXISTS require_attention Boolean;

@

DROP TABLE IF EXISTS `engaged_interface_alerts`;
@
CREATE TABLE `engaged_interface_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`ifid` UInt8 COMMENT 'ntopng internal interface index',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`subtype` String COMMENT 'Alert sub-type string providing additional context',
`name` String COMMENT 'Interface name (e.g. eth0, wlan0)',
`alias` String COMMENT 'User-defined alias for the interface',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = Memory
COMMENT 'In-memory table holding currently active (engaged) interface alerts. Rows are inserted when an alert fires and removed when resolved. Merged with interface_alerts in interface_alerts_view.';

@

CREATE TABLE IF NOT EXISTS `user_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`user` String COMMENT 'ntopng username associated with this alert',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp)
COMMENT 'Historical alerts associated with ntopng-managed users. See engaged_user_alerts for currently-firing alerts and user_alerts_view to query both together.';
@
ALTER TABLE `user_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `user_alerts` ADD COLUMN IF NOT EXISTS require_attention Boolean;

@

DROP TABLE IF EXISTS `engaged_user_alerts`;
@
CREATE TABLE `engaged_user_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`user` String COMMENT 'ntopng username associated with this alert',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = Memory
COMMENT 'In-memory table holding currently active (engaged) user alerts. Rows are inserted when an alert fires and removed when resolved. Merged with user_alerts in user_alerts_view.';

@

CREATE TABLE IF NOT EXISTS `system_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`name` String COMMENT 'Name of the subsystem or component that generated the alert',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp)
COMMENT 'Historical system-level alerts (e.g. license issues, connectivity failures, internal subsystem events). See engaged_system_alerts for currently-firing alerts and system_alerts_view to query both together.';
@
ALTER TABLE `system_alerts` ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `system_alerts` ADD COLUMN IF NOT EXISTS require_attention Boolean;

@

DROP TABLE IF EXISTS `engaged_system_alerts`;
@
CREATE TABLE `engaged_system_alerts` (
`rowid` UUID COMMENT 'Unique identifier for this alert row (UUID v4)',
`alert_id` UInt32 COMMENT 'Alert type identifier (maps to ntopng alert type enum)',
`alert_status` UInt8 COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)',
`interface_id` UInt16 DEFAULT 65535 COMMENT 'ntopng interface identifier; 65535 means system/global scope',
`name` String COMMENT 'Name of the subsystem or component that generated the alert',
`tstamp` DateTime COMMENT 'Timestamp when the alert was first triggered (alert start time)',
`tstamp_end` DateTime COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)',
`severity` UInt8 COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)',
`score` UInt16 COMMENT 'Numeric risk/impact score associated with this alert',
`granularity` UInt8 COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)',
`counter` UInt32 COMMENT 'Number of consecutive intervals this alert condition has been detected',
`description` String COMMENT 'Human-readable description of the alert',
`json` String COMMENT 'Additional alert context and metadata as a JSON blob',
`user_label` String COMMENT 'User-defined free-text label applied to this alert',
`user_label_tstamp` DateTime COMMENT 'Timestamp when user_label was last set',
`alert_category` UInt8 COMMENT 'Alert category (maps to ntopng AlertCategory enum)',
`require_attention` Boolean COMMENT 'True if this alert has been flagged as requiring manual attention'
) ENGINE = Memory
COMMENT 'In-memory table holding currently active (engaged) system alerts. Rows are inserted when an alert fires and removed when resolved. Merged with system_alerts in system_alerts_view.';

@

/* Remove */
DROP TABLE IF EXISTS `aggregated_flows`;
@
CREATE TABLE IF NOT EXISTS `hourly_flows` (
`FLOW_ID` UInt64 COMMENT 'Unique flow identifier assigned by ntopng',
`IP_PROTOCOL_VERSION` UInt8 COMMENT 'IP version: 4 for IPv4, 6 for IPv6',
`FIRST_SEEN` DateTime COMMENT 'Timestamp of the first packet of the flow',
`LAST_SEEN` DateTime COMMENT 'Timestamp of the last packet of the flow',
`VLAN_ID` UInt16 COMMENT '802.1Q VLAN tag (0 if untagged)',
`PACKETS` UInt32 COMMENT 'Total packet count in both directions',
`TOTAL_BYTES` UInt64 COMMENT 'Total bytes transferred in both directions',
`SRC2DST_BYTES` UInt64 /* Total */ COMMENT 'Bytes sent from client (source) to server (destination)',
`DST2SRC_BYTES` UInt64 /* Total */ COMMENT 'Bytes sent from server (destination) to client (source)',
`SCORE` UInt16 /* Total score */ COMMENT 'Composite flow risk/security score',
`PROTOCOL` UInt8 COMMENT 'IP transport protocol number (6=TCP, 17=UDP, 1=ICMP, etc.)',
`IPV4_SRC_ADDR` UInt32 COMMENT 'Source IPv4 address as a 32-bit integer; 0 for IPv6 flows',
`IPV6_SRC_ADDR` IPv6 COMMENT 'Source IPv6 address; all-zeros for IPv4 flows',
`IPV4_DST_ADDR` UInt32 COMMENT 'Destination IPv4 address as a 32-bit integer; 0 for IPv6 flows',
`IPV6_DST_ADDR` IPv6 COMMENT 'Destination IPv6 address; all-zeros for IPv4 flows',
`IP_DST_PORT` UInt16 COMMENT 'Destination (server) port number',
`L7_PROTO` UInt16 COMMENT 'nDPI layer-7 application protocol identifier',
`L7_PROTO_MASTER` UInt16 COMMENT 'nDPI master/carrier protocol ID (e.g. TLS when L7_PROTO is HTTPS)',
`NUM_FLOWS` UInt32 /* Total number of flows that have been aggregated */ COMMENT 'Number of raw flows aggregated into this hourly summary row',
`FLOW_RISK` UInt64 /* OS of flow risk */ COMMENT 'Bitmap of nDPI flow risk flags (each bit represents a distinct risk)',
`SRC_MAC` UInt64 COMMENT 'Source MAC address encoded as a 64-bit integer',
`DST_MAC` UInt64 COMMENT 'Destination MAC address encoded as a 64-bit integer',
`PROBE_IP` UInt32 /* EXPORTER_IPV4_ADDRESS */ COMMENT 'IPv4 address of the NetFlow/IPFIX exporter (probe); same as EXPORTER_IPV4_ADDRESS',
`EXPORTER_SITE` UInt16 COMMENT 'Site/location identifier of the flow exporter',
`NTOPNG_INSTANCE_NAME` String COMMENT 'Hostname/name of the ntopng instance that captured this flow',
`SRC_COUNTRY_CODE` UInt16 COMMENT 'Source IP geo-country: two ASCII letters packed into a UInt16 (high byte = first letter)',
`DST_COUNTRY_CODE` UInt16 COMMENT 'Destination IP geo-country: two ASCII letters packed into a UInt16 (high byte = first letter)',
`SRC_ASN` UInt32 COMMENT 'Autonomous System Number of the source IP',
`DST_ASN` UInt32 COMMENT 'Autonomous System Number of the destination IP',
`INPUT_SNMP` UInt32 COMMENT 'SNMP input interface index exported via NetFlow/IPFIX',
`OUTPUT_SNMP` UInt32 COMMENT 'SNMP output interface index exported via NetFlow/IPFIX',
`SRC_NETWORK_ID` UInt32 COMMENT 'ntopng local-network ID for the source IP (0 if not a known local network)',
`DST_NETWORK_ID` UInt32 COMMENT 'ntopng local-network ID for the destination IP (0 if not a known local network)',
`SRC_LABEL` String COMMENT 'Resolved hostname or user-defined label for the source host',
`DST_LABEL` String COMMENT 'Resolved hostname or user-defined label for the destination host',
`INTERFACE_ID` UInt16 COMMENT 'ntopng internal interface identifier',
`WLAN_SSID` String COMMENT 'Wireless LAN SSID associated with this flow',
`WTP_MAC_ADDRESS` UInt64 COMMENT 'MAC address of the Wireless Termination Point (access point) as a 64-bit integer',
`CLIENT_LOCATION` UInt8 COMMENT 'Client host location type (local LAN, remote, etc.)',
`SERVER_LOCATION` UInt8 COMMENT 'Server host location type (local LAN, remote, etc.)'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(FIRST_SEEN) ORDER BY (FIRST_SEEN, IPV4_SRC_ADDR, IPV4_DST_ADDR)
COMMENT 'Hourly aggregated flow summaries. Multiple raw flows sharing the same 5-tuple are collapsed into one row per hour with summed byte/packet counters and OR-ed risk bitmaps. Used for long-term trend analysis and reduced-resolution historical queries.';
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS SRC_LABEL String;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS DST_LABEL String;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS INTERFACE_ID UInt16;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS WLAN_SSID String;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS WTP_MAC_ADDRESS UInt64;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS CLIENT_LOCATION UInt8;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS SERVER_LOCATION UInt8;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS L7_CATEGORY UInt16;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS `SRC_HOST_POOL_ID` UInt16;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS `DST_HOST_POOL_ID` UInt16;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS `SRC2DST_PACKETS` UInt32;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS `DST2SRC_PACKETS` UInt32;
@
ALTER TABLE `hourly_flows` ADD COLUMN IF NOT EXISTS `EXPORTER_SITE` UInt16;

@

/* VS */

CREATE TABLE IF NOT EXISTS `vulnerability_scan_data` (
`HOST` String COMMENT 'IP address or hostname of the scanned target',
`SCAN_TYPE` String COMMENT 'Type of vulnerability scan performed (e.g. nmap, openvas)',
`LAST_SCAN` DateTime COMMENT 'Timestamp of when this scan was last performed',
`JSON_INFO` String COMMENT 'Full scan results as a JSON blob',
`VS_RESULT_FILE` String COMMENT 'Path to the raw scan result file on disk'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(LAST_SCAN) ORDER BY (LAST_SCAN, HOST, SCAN_TYPE)
COMMENT 'Per-host vulnerability scan results produced by the ntopng Vulnerability Scanner (VS) module. Each row stores the latest scan output for a given host and scan type as a JSON blob.';

@

CREATE TABLE IF NOT EXISTS `vulnerability_scan_report` (
`REPORT_NAME` String COMMENT 'User-defined name for this vulnerability scan report',
`REPORT_DATE` DateTime COMMENT 'Timestamp when the report was generated',
`REPORT_JSON_INFO` String COMMENT 'Full report metadata and summary as a JSON blob',
`NUM_SCANNED_HOSTS` UInt32 COMMENT 'Number of hosts scanned in this report',
`NUM_CVES` UInt32 COMMENT 'Total number of CVEs identified across all scanned hosts',
`NUM_TCP_PORTS` UInt32 COMMENT 'Total number of open TCP ports found across all scanned hosts',
`NUM_UDP_PORTS` UInt32 COMMENT 'Total number of open UDP ports found across all scanned hosts'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(REPORT_DATE) ORDER BY (REPORT_DATE)
COMMENT 'Summary reports of completed vulnerability scans. Each row represents one scan report with aggregate counts of scanned hosts, CVEs found, and open TCP/UDP ports.';

@

/* MITRE */

CREATE TABLE IF NOT EXISTS `mitre_table_info` (
`ALERT_ID` UInt16 COMMENT 'ntopng alert type ID that maps to this MITRE entry',
`ENTITY_ID` UInt16 COMMENT 'ntopng entity type ID (e.g. 1=host, 4=flow) for this mapping',
`TACTIC` UInt16 COMMENT 'MITRE ATT&CK tactic identifier',
`TECHNIQUE` UInt16 COMMENT 'MITRE ATT&CK technique identifier',
`SUB_TECHNIQUE` UInt16 COMMENT 'MITRE ATT&CK sub-technique identifier (0 if none)',
`MITRE_ID` String COMMENT 'MITRE ATT&CK ID string (e.g. T1046, T1595.002)'
) ENGINE = ReplacingMergeTree() PRIMARY KEY (ALERT_ID, ENTITY_ID) ORDER BY (ALERT_ID, ENTITY_ID)
COMMENT 'Mapping of ntopng alert IDs and entity types to MITRE ATT&CK tactics, techniques, and sub-techniques. Joined by host_alerts_view and flow_alerts_view to enrich alert rows with ATT&CK context.';

@

/* ASSET */

CREATE TABLE IF NOT EXISTS `assets` (
`type` String COMMENT 'Asset category (e.g. host, mac, network_device)',
`key` String COMMENT 'Unique asset key within its type (e.g. IP address, MAC address)',
`ifid` UInt8 COMMENT 'ntopng interface on which this asset was observed',
`ip` String DEFAULT '' COMMENT 'IP address of the asset (empty if not applicable)',
`mac` String COMMENT 'MAC address of the asset',
`vlan` UInt16 DEFAULT 0 COMMENT 'VLAN on which the asset was observed (0 if untagged)',
`network` UInt16 DEFAULT 0 COMMENT 'ntopng local-network ID the asset belongs to',
`name` String DEFAULT '' COMMENT 'Resolved hostname or user-defined name',
`device_type` UInt16 DEFAULT 0 COMMENT 'Device category/type (maps to ntopng DeviceType enum)',
`manufacturer` String DEFAULT '' COMMENT 'Hardware manufacturer derived from MAC OUI lookup',
`first_seen` DateTime COMMENT 'Timestamp when this asset was first observed by ntopng',
`last_seen` DateTime COMMENT 'Timestamp of the most recent observation of this asset',
`gateway_mac` String DEFAULT '' COMMENT 'MAC address of the gateway used to reach this asset',
`json_info` String DEFAULT '' -- A json containing all other info
 COMMENT 'Additional asset metadata as a JSON blob (OS info, open ports, etc.)',
`version` UInt64 -- Used to not have duplicates
 COMMENT 'Monotonically increasing version counter used by ReplacingMergeTree for deduplication',
`os_type` String DEFAULT '' COMMENT 'Operating system type detected for this asset',
`model` String DEFAULT '' COMMENT 'Hardware model string for this asset'
) ENGINE = ReplacingMergeTree(version) PRIMARY KEY (`type`, `key`) ORDER BY (`type`, `key`)
COMMENT 'Network asset inventory: one row per discovered or imported asset (host, MAC address, network device). Uses ReplacingMergeTree on version so that re-discovered assets update existing rows rather than creating duplicates. json_info holds additional metadata as a JSON blob.';
@
ALTER TABLE assets ADD COLUMN IF NOT EXISTS `os_type` String;
@
ALTER TABLE assets ADD COLUMN IF NOT EXISTS `model` String;
@


/* VIEWS */

DROP VIEW IF EXISTS `active_monitoring_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `active_monitoring_alerts_view` AS
SELECT * FROM `active_monitoring_alerts`
UNION ALL
SELECT * FROM `engaged_active_monitoring_alerts`

@

DROP VIEW IF EXISTS `mac_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `mac_alerts_view` AS
SELECT * FROM `mac_alerts`
UNION ALL
SELECT * FROM `engaged_mac_alerts`

@

DROP VIEW IF EXISTS `snmp_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `snmp_alerts_view` AS
SELECT * FROM `snmp_alerts`
UNION ALL
SELECT * FROM `engaged_snmp_alerts`

@

DROP VIEW IF EXISTS `network_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `network_alerts_view` AS
SELECT * FROM `network_alerts`
UNION ALL
SELECT * FROM `engaged_network_alerts`

@

DROP VIEW IF EXISTS `as_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `as_alerts_view` AS
SELECT * FROM `as_alerts`
UNION ALL
SELECT * FROM `engaged_as_alerts`

@

DROP VIEW IF EXISTS `interface_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `interface_alerts_view` AS
SELECT * FROM `interface_alerts`
UNION ALL
SELECT * FROM `engaged_interface_alerts`

@

DROP VIEW IF EXISTS `user_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `user_alerts_view` AS
SELECT * FROM `user_alerts`
UNION ALL
SELECT * FROM `engaged_user_alerts`

@

DROP VIEW IF EXISTS `system_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `system_alerts_view` AS
SELECT * FROM `system_alerts`
UNION ALL
SELECT * FROM `engaged_system_alerts`

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
    ha.host_pool_id,
    ha.network,
    ha.country,
    ha.alert_category,
    ha.require_attention,
    mitre.TACTIC AS mitre_tactic,
    mitre.TECHNIQUE AS mitre_technique,
    mitre.SUB_TECHNIQUE AS mitre_subtechnique,
    mitre.MITRE_ID AS mitre_id
FROM
(
    SELECT * FROM `host_alerts`
    UNION ALL
    SELECT * FROM `engaged_host_alerts`
)
    AS ha
LEFT JOIN
    `mitre_table_info` AS mitre
ON
    (mitre.ENTITY_ID = 1 AND ha.alert_id = mitre.ALERT_ID);

@

DROP TABLE IF EXISTS `flow_alerts`;
@
DROP VIEW IF EXISTS `flow_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `flow_alerts_view` AS
SELECT
    f.FLOW_ID AS rowid,
    f.IP_PROTOCOL_VERSION AS ip_version,
    f.FIRST_SEEN AS tstamp,
    f.FIRST_SEEN AS first_seen,
    f.LAST_SEEN AS tstamp_end,
    f.VLAN_ID AS vlan_id,
    f.PACKETS AS packets,
    f.TOTAL_BYTES AS total_bytes,
    f.SRC2DST_PACKETS AS cli2srv_pkts,
    f.DST2SRC_PACKETS AS srv2cli_pkts,
    f.SRC2DST_BYTES AS cli2srv_bytes,
    f.DST2SRC_BYTES AS srv2cli_bytes,
    f.SRC2DST_DSCP AS src2dst_dscp,
    f.DST2SRC_DSCP AS dst2src_dscp,
    f.PROTOCOL AS proto,
    IF(f.IPV4_SRC_ADDR != 0, IPv4NumToString(f.IPV4_SRC_ADDR), IPv6NumToString(f.IPV6_SRC_ADDR)) AS cli_ip,
    IF(f.IPV4_DST_ADDR != 0, IPv4NumToString(f.IPV4_DST_ADDR), IPv6NumToString(f.IPV6_DST_ADDR)) AS srv_ip,
    f.IP_SRC_PORT AS cli_port,
    f.IP_DST_PORT AS srv_port,
    f.L7_PROTO AS l7_proto,
    f.L7_PROTO_MASTER AS l7_master_proto,
    f.L7_CATEGORY AS l7_cat,
    f.NTOPNG_INSTANCE_NAME AS ntopng_instance_name,
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
    f.SRC_ASN AS src_asn,
    f.DST_ASN AS dst_asn,
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
    f.SRC2DST_TCP_FLAGS AS src2dst_tcp_flags,
    f.DST2SRC_TCP_FLAGS AS dst2src_tcp_flags,
    f.INPUT_SNMP AS input_snmp,
    f.OUTPUT_SNMP AS output_snmp,
    f.ALERT_CATEGORY AS alert_category,
    f.MINOR_CONNECTION_STATE AS minor_connection_state,
    f.MAJOR_CONNECTION_STATE AS major_connection_state,
    f.REQUIRE_ATTENTION AS require_attention,
    mitre.TACTIC AS mitre_tactic,
    mitre.TECHNIQUE AS mitre_technique,
    mitre.SUB_TECHNIQUE AS mitre_subtechnique,
    mitre.MITRE_ID AS mitre_id
FROM `flows` AS f
LEFT JOIN `mitre_table_info` AS mitre
    ON (mitre.ENTITY_ID = 4 AND f.STATUS = mitre.ALERT_ID)
WHERE f.STATUS != 0
    AND f.IS_ALERT_DELETED != 1;

@

DROP VIEW IF EXISTS `all_alerts_view`;
@
CREATE VIEW IF NOT EXISTS `all_alerts_view` AS
SELECT 8 entity_id, interface_id, alert_id, alert_status, require_attention, tstamp, tstamp_end, severity, score, alert_category FROM `active_monitoring_alerts_view`
UNION ALL
SELECT 4 entity_id, INTERFACE_ID AS interface_id, STATUS AS alert_id, ALERT_STATUS AS alert_status, REQUIRE_ATTENTION AS require_attention, FIRST_SEEN AS tstamp, LAST_SEEN AS tstamp_end, SEVERITY AS severity, SCORE AS score, ALERT_CATEGORY AS alert_category FROM `flows` WHERE (STATUS != 0 AND IS_ALERT_DELETED != 1)
UNION ALL
SELECT 1 entity_id, interface_id, alert_id, alert_status, require_attention, tstamp, tstamp_end, severity, score, alert_category FROM `host_alerts_view`
UNION ALL
SELECT 5 entity_id, interface_id, alert_id, alert_status, require_attention, tstamp, tstamp_end, severity, score, alert_category FROM `mac_alerts_view`
UNION ALL
SELECT 3 entity_id, interface_id, alert_id, alert_status, require_attention, tstamp, tstamp_end, severity, score, alert_category FROM `snmp_alerts_view`
UNION ALL
SELECT 2 entity_id, interface_id, alert_id, alert_status, require_attention, tstamp, tstamp_end, severity, score, alert_category FROM `network_alerts_view`
UNION ALL
SELECT 0 entity_id, interface_id, alert_id, alert_status, require_attention, tstamp, tstamp_end, severity, score, alert_category FROM `interface_alerts_view`
UNION ALL
SELECT 7 entity_id, interface_id, alert_id, alert_status, require_attention, tstamp, tstamp_end, severity, score, alert_category FROM `user_alerts_view`
UNION ALL
SELECT 9 entity_id, interface_id, alert_id, alert_status, require_attention, tstamp, tstamp_end, severity, score, alert_category FROM `system_alerts_view`
UNION ALL
SELECT 10 entity_id, interface_id, alert_id, alert_status, require_attention, tstamp, tstamp_end, severity, score, alert_category FROM `as_alerts_view`
;

@

/* IMPORTANT: keep in sync with db_schema_as_sqlite.sql */
CREATE TABLE IF NOT EXISTS `hourly_asn` (
`ID` UInt64 COMMENT 'Unique row identifier',
`NTOPNG_INSTANCE_NAME` String COMMENT 'Name of the ntopng instance that generated this record',
`INTERFACE_ID` UInt16 COMMENT 'ntopng interface identifier on which this traffic was observed',
`IP_PROTOCOL_VERSION` UInt8 COMMENT 'IP version: 4 for IPv4, 6 for IPv6',
`FIRST_SEEN` DateTime COMMENT 'Start of the one-hour aggregation window',
`LAST_SEEN` DateTime COMMENT 'End of the one-hour aggregation window',
`SRC2DST_BYTES` UInt64 COMMENT 'Bytes from source ASN to destination ASN in this hour',
`DST2SRC_BYTES` UInt64 COMMENT 'Bytes from destination ASN to source ASN in this hour',
`TOTAL_BYTES` UInt64 COMMENT 'Total bytes between the two ASNs in this hour',
`SRC2DST_PACKETS` UInt32 COMMENT 'Packets from source ASN to destination ASN in this hour',
`DST2SRC_PACKETS` UInt32 COMMENT 'Packets from destination ASN to source ASN in this hour',
`SRC_ASN` UInt32 COMMENT 'Autonomous System Number of the source',
`DST_ASN` UInt32 COMMENT 'Autonomous System Number of the destination',
`SRC_PEER_ASN` UInt32 COMMENT 'BGP peer ASN upstream of the source (EXPORTER_IPV4_ADDRESS)',
`DST_PEER_ASN` UInt32 COMMENT 'BGP peer ASN upstream of the destination',
`PROBE_IP` UInt32 /* EXPORTER_IPV4_ADDRESS */ COMMENT 'IPv4 address of the NetFlow/IPFIX exporter; same as EXPORTER_IPV4_ADDRESS',
`INPUT_SNMP` UInt32 COMMENT 'SNMP input interface index from NetFlow/IPFIX',
`OUTPUT_SNMP` UInt32 COMMENT 'SNMP output interface index from NetFlow/IPFIX'
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(FIRST_SEEN) ORDER BY (FIRST_SEEN, SRC_ASN, DST_ASN)
COMMENT 'Hourly aggregated traffic statistics per source/destination ASN pair. Used for autonomous-system level traffic analysis and BGP peer analytics. Partitioned by day on FIRST_SEEN.';
@
ALTER TABLE `hourly_asn` ADD COLUMN IF NOT EXISTS TOTAL_BYTES UInt64;

@

CREATE TABLE IF NOT EXISTS ai_chat_history (
    chat_id UUID COMMENT 'Unique identifier for a chat session',
    sequence UInt32 COMMENT 'Seq number to preserve message order within a chat',
    created_at DateTime COMMENT 'Message creation timestamp',
    username String COMMENT 'Identifier of the user who created the chat',
    message_role UInt8 COMMENT 'Role of message sender (user = 1 or assistant = 2 )',
    message_content String COMMENT 'Raw message content (user input or assistant response)',
    provider String COMMENT 'LLM provider used (local llm, anthropic, openAI)',
    model String COMMENT 'Model name used for generation',
    completion_time_sec UInt32 COMMENT 'Time taken to generate the assistant response (seconds)',
    tokens_per_second UInt32 COMMENT 'Generation speed in tokens per second',
    artifact_json String DEFAULT '' COMMENT 'JSON-encoded artifact spec (chart, ping, etc.) for assistant messages; empty for user messages',
    evidence_json String DEFAULT '' COMMENT 'JSON audit trail of how the answer was produced: tool calls with inputs and result metadata',
) ENGINE = MergeTree() PARTITION BY toYYYYMMDD(created_at) ORDER BY (chat_id, sequence)
COMMENT 'Chat history table storing user and assistant messages for conversations';

@

CREATE TABLE IF NOT EXISTS ai_token_usage (
    chat_id           UUID                   COMMENT 'Links to ai_chat_history session',
    call_seq          UInt32                 COMMENT 'Iteration index within the agentic loop (1-based)',
    chat_title        String DEFAULT ''      COMMENT 'Title of the chat (first user message, populated only on call_seq=1 of sequence=1)',
    created_at        DateTime               COMMENT 'Timestamp of this LLM API call',
    username          String                 COMMENT 'User who owns the chat',
    call_type         LowCardinality(String) COMMENT 'initial_call | tool_followup | final_response | retry',
    provider          LowCardinality(String) COMMENT 'LLM provider (llm_local, llm_anthropic, llm_openai)',
    model             LowCardinality(String) COMMENT 'Model name used for this call',
    prompt_tokens     UInt32                 COMMENT 'Tokens sent to the model (input)',
    completion_tokens UInt32                 COMMENT 'Tokens generated by the model (output)',
    completion_time_ms UInt32                COMMENT 'Wall time for this LLM call in milliseconds',
    tool_name         LowCardinality(String) COMMENT 'Tool dispatched in this call (empty if not a tool call)',
    tool_params       String                 COMMENT 'Raw parameters passed to the tool (empty if not a tool call)'
) ENGINE = MergeTree()
  PARTITION BY toYYYYMMDD(created_at)
  ORDER BY (username, chat_id, call_seq)
COMMENT 'Per-LLM-call token accounting for cost and usage analysis';

@

CREATE TABLE IF NOT EXISTS ai_model_prices (
    provider          LowCardinality(String) COMMENT 'LLM provider (llm_local, llm_anthropic, llm_openai)',
    model             LowCardinality(String) COMMENT 'Model name',
    input_price_usd   Float64 DEFAULT 0     COMMENT 'Cost per million input/prompt tokens in USD',
    output_price_usd  Float64 DEFAULT 0     COMMENT 'Cost per million output/completion tokens in USD',
    updated_at        DateTime DEFAULT now() COMMENT 'Last update timestamp'
) ENGINE = ReplacingMergeTree(updated_at)
  ORDER BY (provider, model)
COMMENT 'Model pricing configuration for LLM cost calculation';
