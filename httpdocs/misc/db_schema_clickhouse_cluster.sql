/* Keep flows columns definition in sync with: */
/* - httpdocs/misc/db_schema_clickhouse.sql */
/* - pro/include/FlowsTable.h */
/* - pro/src/ClickHouseDB.cpp -> ClickHouseDB::dumpFlow() */
/* - scripts/lua/modules/tag_utils.lua -> By adding the new tags for filters */
/* - scripts/lua/modules/historical_flow_utils.lua -> Columns mapping */
/* - doc/README.clickhouse_schema.md */

USE ntopng;

@

CREATE TABLE IF NOT EXISTS `flows` ON CLUSTER '$CLUSTER' (
`FLOW_ID` UInt64,
`IP_PROTOCOL_VERSION` UInt8,
`FIRST_SEEN` DateTime,
`LAST_SEEN` DateTime,
`VLAN_ID` UInt16 /* LowCardinality */,
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
`SRC_ASN` UInt32,
`DST_ASN` UInt32,
`PROBE_IP` IPv6,
`EXPORTER_SITE` UInt16,
`INTERFACE_ROLE` UInt8,
`OBSERVATION_POINT_ID` UInt16,
`SRC2DST_TCP_FLAGS` UInt8,
`DST2SRC_TCP_FLAGS` UInt8,
`SCORE` UInt16,
`QOE_SCORE` UInt8,
`CLIENT_NW_LATENCY_US` UInt32,
`SERVER_NW_LATENCY_US` UInt32,
`CLIENT_LOCATION` UInt8,
`SERVER_LOCATION` UInt8,
`SRC_NETWORK_ID` UInt32,
`DST_NETWORK_ID` UInt32,
`SRC_SITE_ID` UInt16,
`DST_SITE_ID` UInt16,
`CLIENT_FINGERPRINT` String,
`INPUT_SNMP` UInt32,
`OUTPUT_SNMP` UInt32,
`SRC_HOST_POOL_ID` UInt16,
`DST_HOST_POOL_ID` UInt16,
`SRC_PROC_NAME` String,
`DST_PROC_NAME` String,
`SRC_PROC_USER_NAME` String,
`DST_PROC_USER_NAME` String,
`ALERTS_MAP` String,
`TAGS_MAP` String,
`SRC_TAGS_MAP` String,
`DST_TAGS_MAP` String,
`SEVERITY` UInt8,
`IS_CLI_ATTACKER` UInt8,
`IS_CLI_VICTIM` UInt8,
`IS_CLI_BLACKLISTED` UInt8,
`IS_SRV_ATTACKER` UInt8,
`IS_SRV_VICTIM` UInt8,
`IS_SRV_BLACKLISTED` UInt8,
`ALERT_STATUS` UInt8,
`USER_LABEL` String,
`USER_LABEL_TSTAMP` DateTime,
`PROTOCOL_INFO_JSON` String,
`ALERT_JSON` String,
`IS_ALERT_DELETED` UInt8,
`SRC2DST_PACKETS` UInt32,
`DST2SRC_PACKETS` UInt32,
`ALERT_CATEGORY` UInt8,
`MINOR_CONNECTION_STATE` UInt8,
`MAJOR_CONNECTION_STATE` UInt8,
`POST_NAT_IPV4_SRC_ADDR` UInt32,
`POST_NAT_SRC_PORT` UInt32,
`POST_NAT_IPV4_DST_ADDR` UInt32,
`POST_NAT_DST_PORT` UInt32,
`DOMAIN_NAME` String,
`SRC_PEER_ASN` UInt32,
`DST_PEER_ASN` UInt32,
`REQUIRE_ATTENTION` Boolean,
`NEXT_ADJACENT_ASN` UInt32,
`HR_SRC2DST_BYTES` Array(UInt64),
`HR_DST2SRC_BYTES` Array(UInt64),
`IS_FIRST_DUMP` Boolean,
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(FIRST_SEEN) ORDER BY (FIRST_SEEN, IPV4_SRC_ADDR, IPV4_DST_ADDR);
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `FLOW_ID` UInt64;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `CLIENT_NW_LATENCY_US` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SERVER_NW_LATENCY_US` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `CLIENT_LOCATION` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SERVER_LOCATION` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC_NETWORK_ID` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST_NETWORK_ID` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `CLIENT_FINGERPRINT` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `INPUT_SNMP` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `OUTPUT_SNMP` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC_HOST_POOL_ID` UInt16;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST_HOST_POOL_ID` UInt16;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC_PROC_NAME` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST_PROC_NAME` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC_PROC_USER_NAME` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST_PROC_USER_NAME` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `ALERTS_MAP` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `TAGS_MAP` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC_TAGS_MAP` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST_TAGS_MAP` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SEVERITY` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `IS_CLI_ATTACKER` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `IS_CLI_VICTIM` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `IS_CLI_BLACKLISTED` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `IS_SRV_ATTACKER` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `IS_SRV_VICTIM` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `IS_SRV_BLACKLISTED` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `ALERT_STATUS` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `USER_LABEL` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `USER_LABEL_TSTAMP` DateTime;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `PROTOCOL_INFO_JSON` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `ALERT_JSON` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `IS_ALERT_DELETED` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC2DST_PACKETS` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST2SRC_PACKETS` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `ALERT_CATEGORY` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `MINOR_CONNECTION_STATE` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `MAJOR_CONNECTION_STATE` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `POST_NAT_IPV4_SRC_ADDR` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `POST_NAT_SRC_PORT` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `POST_NAT_IPV4_DST_ADDR` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `POST_NAT_DST_PORT` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DOMAIN_NAME` String;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `REQUIRE_ATTENTION` Boolean;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `QOE_SCORE` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC_PEER_ASN` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST_PEER_ASN` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `NEXT_ADJACENT_ASN` UInt32;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `EXPORTER_SITE` UInt16;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `HR_SRC2DST_BYTES` Array(UInt64);
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `HR_DST2SRC_BYTES` Array(UInt64);
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `INTERFACE_ROLE` UInt8;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `IS_FIRST_DUMP` Boolean;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC_SITE_ID` UInt16;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST_SITE_ID` UInt16;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `PROBE_IP` IPv6;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' DROP COLUMN IF EXISTS `PRE_NAT_IPV4_SRC_ADDR`;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' DROP COLUMN IF EXISTS `PRE_NAT_SRC_PORT`;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' DROP COLUMN IF EXISTS `PRE_NAT_IPV4_DST_ADDR`;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' DROP COLUMN IF EXISTS `PRE_NAT_DST_PORT`;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' DROP COLUMN IF EXISTS `COMMUNITY_ID`;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' DROP COLUMN IF EXISTS `TCP_FINGERPRINT`;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' DROP COLUMN IF EXISTS `WLAN_SSID`;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' DROP COLUMN IF EXISTS `WTP_MAC_ADDRESS`;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' DROP COLUMN IF EXISTS `LABELS_MAP`;
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Per-flow telemetry records captured locally or received via NetFlow/sFlow/IPFIX. Each row represents one bidirectional network flow with 5-tuple (src/dst IP, src/dst port, protocol), byte/packet counters, L7 application identification, flow-risk bitmap, DSCP, NAT addresses, process info, and optional alert metadata. Partitioned by day on FIRST_SEEN.';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `FLOW_ID` COMMENT 'Unique flow identifier assigned by ntopng';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IP_PROTOCOL_VERSION` COMMENT 'IP version: 4 for IPv4, 6 for IPv6';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `FIRST_SEEN` COMMENT 'Timestamp of the first packet of the flow';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `LAST_SEEN` COMMENT 'Timestamp of the last packet of the flow';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `VLAN_ID` COMMENT '802.1Q VLAN tag (0 if untagged)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PACKETS` COMMENT 'Total packet count in both directions';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `TOTAL_BYTES` COMMENT 'Total bytes transferred in both directions';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC2DST_BYTES` COMMENT 'Bytes sent from client (source) to server (destination)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST2SRC_BYTES` COMMENT 'Bytes sent from server (destination) to client (source)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC2DST_DSCP` COMMENT 'DSCP value observed in the client-to-server direction';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST2SRC_DSCP` COMMENT 'DSCP value observed in the server-to-client direction';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PROTOCOL` COMMENT 'IP transport protocol number (6=TCP, 17=UDP, 1=ICMP, etc.)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IPV4_SRC_ADDR` COMMENT 'Source IPv4 address as a 32-bit integer; 0 for IPv6 flows';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IPV6_SRC_ADDR` COMMENT 'Source IPv6 address; all-zeros for IPv4 flows';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IP_SRC_PORT` COMMENT 'Source (client) port number';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IPV4_DST_ADDR` COMMENT 'Destination IPv4 address as a 32-bit integer; 0 for IPv6 flows';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IPV6_DST_ADDR` COMMENT 'Destination IPv6 address; all-zeros for IPv4 flows';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IP_DST_PORT` COMMENT 'Destination (server) port number';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `L7_PROTO` COMMENT 'nDPI layer-7 application protocol identifier';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `L7_PROTO_MASTER` COMMENT 'nDPI master/carrier protocol ID (e.g. TLS when L7_PROTO is HTTPS)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `L7_CATEGORY` COMMENT 'nDPI application category identifier';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `FLOW_RISK` COMMENT 'Bitmap of nDPI flow risk flags (each bit represents a distinct risk)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `INFO` COMMENT 'Supplementary flow info extracted by nDPI (e.g. HTTP host, DNS query name, TLS SNI)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PROFILE` COMMENT 'Traffic policy profile name matched by this flow';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `NTOPNG_INSTANCE_NAME` COMMENT 'Hostname/name of the ntopng instance that captured this flow';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `INTERFACE_ID` COMMENT 'ntopng internal interface identifier';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `STATUS` COMMENT 'Flow alert type ID (0 = normal non-alert flow; non-zero = alert type)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_COUNTRY_CODE` COMMENT 'Source IP geo-country: two ASCII letters packed into a UInt16 (high byte = first letter)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_COUNTRY_CODE` COMMENT 'Destination IP geo-country: two ASCII letters packed into a UInt16 (high byte = first letter)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_LABEL` COMMENT 'Resolved hostname or user-defined label for the source host';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_LABEL` COMMENT 'Resolved hostname or user-defined label for the destination host';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_MAC` COMMENT 'Source MAC address encoded as a 64-bit integer';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_MAC` COMMENT 'Destination MAC address encoded as a 64-bit integer';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_ASN` COMMENT 'Autonomous System Number of the source IP';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_ASN` COMMENT 'Autonomous System Number of the destination IP';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PROBE_IP` COMMENT 'IPv4 or IPv6 address of the NetFlow/IPFIX exporter (probe); IPv4 addresses are stored as IPv4-mapped IPv6 (::ffff:a.b.c.d)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `EXPORTER_SITE` COMMENT 'Site/location identifier of the flow exporter';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `INTERFACE_ROLE` COMMENT 'Role of the SMMP interface where 0 = other, 1 = transit, 2 = peering, 3 = internal interface, 4 = internet exchange';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `OBSERVATION_POINT_ID` COMMENT 'IPFIX observation point identifier';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC2DST_TCP_FLAGS` COMMENT 'Bitwise OR of TCP flags seen in the client-to-server direction';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST2SRC_TCP_FLAGS` COMMENT 'Bitwise OR of TCP flags seen in the server-to-client direction';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SCORE` COMMENT 'Composite flow risk/security score';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `QOE_SCORE` COMMENT 'Quality of Experience score (0=best)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `CLIENT_NW_LATENCY_US` COMMENT 'Estimated client-side network RTT in microseconds';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SERVER_NW_LATENCY_US` COMMENT 'Estimated server-side network RTT in microseconds';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `CLIENT_LOCATION` COMMENT 'Client host location type (local LAN, remote, etc.)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SERVER_LOCATION` COMMENT 'Server host location type (local LAN, remote, etc.)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_NETWORK_ID` COMMENT 'ntopng local-network ID for the source IP (0 if not a known local network)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_NETWORK_ID` COMMENT 'ntopng local-network ID for the destination IP (0 if not a known local network)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_SITE_ID` COMMENT 'ntopng site ID associated with the source network (0 if none)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_SITE_ID` COMMENT 'ntopng site ID associated with the destination network (0 if none)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `CLIENT_FINGERPRINT` COMMENT 'TLS/QUIC client fingerprint (JA3 or similar)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `INPUT_SNMP` COMMENT 'SNMP input interface index exported via NetFlow/IPFIX';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `OUTPUT_SNMP` COMMENT 'SNMP output interface index exported via NetFlow/IPFIX';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_HOST_POOL_ID` COMMENT 'ntopng host-pool ID of the source host';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_HOST_POOL_ID` COMMENT 'ntopng host-pool ID of the destination host';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_PROC_NAME` COMMENT 'Name of the OS process that originated the flow (from eBPF/sysdig)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_PROC_NAME` COMMENT 'Name of the OS process that received the flow (from eBPF/sysdig)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_PROC_USER_NAME` COMMENT 'OS username owning the source process';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_PROC_USER_NAME` COMMENT 'OS username owning the destination process';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ALERTS_MAP` COMMENT 'Serialized bitmap of individual alert conditions triggered on this flow';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `TAGS_MAP` COMMENT 'Serialized bitmap of tags associated with this flow';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_TAGS_MAP` COMMENT 'Serialized bitmap of tags associated with the source host';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_TAGS_MAP` COMMENT 'Serialized bitmap of tags associated with the destination host';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SEVERITY` COMMENT 'Alert severity level; meaningful only when STATUS != 0';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IS_CLI_ATTACKER` COMMENT '1 if the client host is flagged as an attacker, 0 otherwise';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IS_CLI_VICTIM` COMMENT '1 if the client host is flagged as a victim, 0 otherwise';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IS_CLI_BLACKLISTED` COMMENT '1 if the client IP appears on a threat-intel blacklist, 0 otherwise';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IS_SRV_ATTACKER` COMMENT '1 if the server host is flagged as an attacker, 0 otherwise';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IS_SRV_VICTIM` COMMENT '1 if the server host is flagged as a victim, 0 otherwise';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IS_SRV_BLACKLISTED` COMMENT '1 if the server IP appears on a threat-intel blacklist, 0 otherwise';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ALERT_STATUS` COMMENT 'Alert lifecycle status (e.g. acknowledged, in-progress)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `USER_LABEL` COMMENT 'User-defined free-text label applied to this flow';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `USER_LABEL_TSTAMP` COMMENT 'Timestamp when USER_LABEL was last modified';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PROTOCOL_INFO_JSON` COMMENT 'Protocol-specific metadata (HTTP URL, DNS answers, TLS cert info, etc.) as JSON';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ALERT_JSON` COMMENT 'Alert-specific context and evidence as a JSON blob';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IS_ALERT_DELETED` COMMENT '1 if the alert on this flow was manually acknowledged/deleted, 0 otherwise';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC2DST_PACKETS` COMMENT 'Packet count from client (source) to server (destination)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST2SRC_PACKETS` COMMENT 'Packet count from server (destination) to client (source)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ALERT_CATEGORY` COMMENT 'Alert category identifier (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `MINOR_CONNECTION_STATE` COMMENT 'Fine-grained TCP/flow connection state';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `MAJOR_CONNECTION_STATE` COMMENT 'Coarse TCP connection state (e.g. established, closing, closed)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `POST_NAT_IPV4_SRC_ADDR` COMMENT 'Source IPv4 address after NAT translation';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `POST_NAT_SRC_PORT` COMMENT 'Source port after NAT translation';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `POST_NAT_IPV4_DST_ADDR` COMMENT 'Destination IPv4 address after NAT translation';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `POST_NAT_DST_PORT` COMMENT 'Destination port after NAT translation';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DOMAIN_NAME` COMMENT 'Domain name extracted from the flow (from SNI, DNS, or HTTP Host header)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_PEER_ASN` COMMENT 'BGP peer ASN upstream of the source IP';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_PEER_ASN` COMMENT 'BGP peer ASN upstream of the destination IP';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `REQUIRE_ATTENTION` COMMENT 'True if this flow/alert has been flagged as requiring manual review';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `NEXT_ADJACENT_ASN` COMMENT 'BGP next adjacent ASN (BGP_NEXT_ADJACENT_ASN / IPFIX field 128)';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `HR_SRC2DST_BYTES` COMMENT '15-second delta byte counters src->dst from nProbe high-resolution counters';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `HR_DST2SRC_BYTES` COMMENT '15-second delta byte counters dst->src from nProbe high-resolution counters';
@
ALTER TABLE `flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IS_FIRST_DUMP` COMMENT 'True if this is the first time this flow is dumped to DB (i.e. it is a new flow), or false if this flows has been previously dumped (i.e. it is a continuation)';

@

CREATE TABLE IF NOT EXISTS `active_monitoring_alerts` ON CLUSTER '$CLUSTER' (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`resolved_ip` String,
`resolved_name` String,
`measurement` String,
`measure_threshold` UInt32 DEFAULT 0,
`measure_value` REAL DEFAULT 0.0,
`tstamp` DateTime,
`tstamp_end` DateTime DEFAULT toDateTime(0),
`severity` UInt8,
`score` UInt16,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime DEFAULT toDateTime(0),
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS require_attention Boolean;
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Historical alerts generated by the active monitoring subsystem (ICMP ping, HTTP, TLS checks, etc.). Rows are appended when an engaged alert is archived. See engaged_active_monitoring_alerts for currently-firing alerts and active_monitoring_alerts_view to query both together.';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `resolved_ip` COMMENT 'IP address resolved from the monitored hostname at time of check';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `resolved_name` COMMENT 'Hostname or target being monitored (FQDN or IP)';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `measurement` COMMENT 'Type of active monitoring check (e.g. icmp, http, https, tls)';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `measure_threshold` COMMENT 'Configured threshold value that was exceeded to trigger the alert';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `measure_value` COMMENT 'Measured value (e.g. latency in ms, HTTP response code) at alert time';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';
@

DROP TABLE IF EXISTS `engaged_active_monitoring_alerts`;
@
CREATE TABLE `engaged_active_monitoring_alerts` (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16  DEFAULT 65535,
`resolved_ip` String,
`resolved_name` String,
`measurement` String,
`measure_threshold` UInt32 DEFAULT 0,
`measure_value` REAL DEFAULT 0.0,
`tstamp` DateTime,
`tstamp_end` DateTime DEFAULT toDateTime(0),
`severity` UInt8,
`score` UInt16,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime DEFAULT toDateTime(0),
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = Memory;
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'In-memory table holding currently active (engaged) active-monitoring alerts. Rows are inserted when an alert fires and removed when resolved. Merged with active_monitoring_alerts in active_monitoring_alerts_view.';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `resolved_ip` COMMENT 'IP address resolved from the monitored hostname at time of check';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `resolved_name` COMMENT 'Hostname or target being monitored (FQDN or IP)';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `measurement` COMMENT 'Type of active monitoring check (e.g. icmp, http, https, tls)';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `measure_threshold` COMMENT 'Configured threshold value that was exceeded to trigger the alert';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `measure_value` COMMENT 'Measured value (e.g. latency in ms, HTTP response code) at alert time';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `engaged_active_monitoring_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

CREATE TABLE IF NOT EXISTS `host_alerts` ON CLUSTER '$CLUSTER' (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`ip_version` UInt8,
`ip` String,
`vlan_id` UInt16,
`name` String,
`is_attacker` UInt8,
`is_victim` UInt8,
`is_client` UInt8,
`is_server` UInt8,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`host_pool_id` UInt16,
`network` UInt16,
`country` String,
`alert_category` UInt8,
`require_attention` Boolean,
`tags_map` String DEFAULT ''
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS host_pool_id UInt16;
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS network UInt16;
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `country` String;
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS require_attention Boolean;
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `tags_map` String DEFAULT '';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' DROP COLUMN IF EXISTS `labels_map`;
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Historical alerts associated with individual hosts (identified by IP address and VLAN). Rows are appended when an engaged host alert is archived. See engaged_host_alerts for currently-firing alerts and host_alerts_view to query both together (with MITRE ATT&CK enrichment).';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ip_version` COMMENT 'IP version of the host: 4 for IPv4, 6 for IPv6';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ip` COMMENT 'IP address of the host that triggered the alert';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `vlan_id` COMMENT 'VLAN on which the host was observed (0 if untagged)';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'Resolved hostname or user-defined name for the host';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_attacker` COMMENT '1 if the host is the attacking party in this alert';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_victim` COMMENT '1 if the host is the victim party in this alert';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_client` COMMENT '1 if the host acted as a client in the triggering flow';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_server` COMMENT '1 if the host acted as a server in the triggering flow';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `host_pool_id` COMMENT 'ntopng host-pool ID the host belongs to';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `network` COMMENT 'ntopng local-network ID the host belongs to';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `country` COMMENT 'Two-letter ISO 3166-1 country code derived from the host IP';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';
@
ALTER TABLE `host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tags_map` COMMENT 'HEX-encoded bitmap of host tags set at the time the alert triggered';

@

DROP TABLE IF EXISTS `engaged_host_alerts`;
@
CREATE TABLE `engaged_host_alerts` (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`ip_version` UInt8,
`ip` String,
`vlan_id` UInt16,
`name` String,
`is_attacker` UInt8,
`is_victim` UInt8,
`is_client` UInt8,
`is_server` UInt8,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`host_pool_id` UInt16,
`network` UInt16,
`country` String,
`alert_category` UInt8,
`require_attention` Boolean,
`tags_map` String DEFAULT ''
) ENGINE = Memory;
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'In-memory table holding currently active (engaged) host alerts. Rows are inserted when an alert fires and removed when resolved. Merged with host_alerts in host_alerts_view.';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ip_version` COMMENT 'IP version of the host: 4 for IPv4, 6 for IPv6';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ip` COMMENT 'IP address of the host that triggered the alert';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `vlan_id` COMMENT 'VLAN on which the host was observed (0 if untagged)';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'Resolved hostname or user-defined name for the host';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_attacker` COMMENT '1 if the host is the attacking party in this alert';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_victim` COMMENT '1 if the host is the victim party in this alert';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_client` COMMENT '1 if the host acted as a client in the triggering flow';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_server` COMMENT '1 if the host acted as a server in the triggering flow';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `host_pool_id` COMMENT 'ntopng host-pool ID the host belongs to';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `network` COMMENT 'ntopng local-network ID the host belongs to';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `country` COMMENT 'Two-letter ISO 3166-1 country code derived from the host IP';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';
@
ALTER TABLE `engaged_host_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tags_map` COMMENT 'HEX-encoded bitmap of host tags set at the time the alert triggered';

@

CREATE TABLE IF NOT EXISTS `mac_alerts` ON CLUSTER '$CLUSTER' (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`address` String,
`device_type` UInt8 DEFAULT 0,
`name` String,
`is_attacker` UInt8,
`is_victim` UInt8,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS require_attention Boolean;
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Historical alerts associated with MAC addresses and layer-2 devices. See engaged_mac_alerts for currently-firing alerts and mac_alerts_view to query both together.';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `address` COMMENT 'MAC address of the device that triggered the alert (colon-separated hex)';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `device_type` COMMENT 'Device category/type identifier (maps to ntopng DeviceType enum)';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'User-defined or discovered name for the device';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_attacker` COMMENT '1 if the device is the attacking party in this alert';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_victim` COMMENT '1 if the device is the victim party in this alert';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

DROP TABLE IF EXISTS `engaged_mac_alerts`;
@
CREATE TABLE `engaged_mac_alerts` (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`address` String,
`device_type` UInt8 DEFAULT 0,
`name` String,
`is_attacker` UInt8,
`is_victim` UInt8,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = Memory;
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'In-memory table holding currently active (engaged) MAC/device alerts. Rows are inserted when an alert fires and removed when resolved. Merged with mac_alerts in mac_alerts_view.';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `address` COMMENT 'MAC address of the device that triggered the alert (colon-separated hex)';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `device_type` COMMENT 'Device category/type identifier (maps to ntopng DeviceType enum)';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'User-defined or discovered name for the device';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_attacker` COMMENT '1 if the device is the attacking party in this alert';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `is_victim` COMMENT '1 if the device is the victim party in this alert';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `engaged_mac_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

CREATE TABLE IF NOT EXISTS `snmp_alerts` ON CLUSTER '$CLUSTER' (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`ip` String,
`port` UInt32,
`name` String,
`port_name` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Historical alerts from SNMP-polled network devices and their individual ports. See engaged_snmp_alerts for currently-firing alerts and snmp_alerts_view to query both together.';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `port` UInt32;
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS require_attention Boolean;
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ip` COMMENT 'IP address of the SNMP-polled device that triggered the alert';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `port` COMMENT 'SNMP interface index (ifIndex) of the interface that triggered the alert';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'SNMP sysName or user-defined name of the device';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `port_name` COMMENT 'SNMP ifDescr or user-defined name of the triggering interface';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

DROP TABLE IF EXISTS `engaged_snmp_alerts`;
@
CREATE TABLE `engaged_snmp_alerts` (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`ip` String,
`port` UInt32,
`name` String,
`port_name` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = Memory;
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'In-memory table holding currently active (engaged) SNMP alerts. Rows are inserted when an alert fires and removed when resolved. Merged with snmp_alerts in snmp_alerts_view.';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ip` COMMENT 'IP address of the SNMP-polled device that triggered the alert';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `port` COMMENT 'SNMP interface index (ifIndex) of the interface that triggered the alert';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'SNMP sysName or user-defined name of the device';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `port_name` COMMENT 'SNMP ifDescr or user-defined name of the triggering interface';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `engaged_snmp_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

CREATE TABLE IF NOT EXISTS `network_alerts` ON CLUSTER '$CLUSTER' (
`rowid` UUID,
`local_network_id` UInt16,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`name` String,
`alias` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS require_attention Boolean;
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Historical alerts associated with local network subnets (identified by local_network_id). See engaged_network_alerts for currently-firing alerts and network_alerts_view to query both together.';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `local_network_id` COMMENT 'ntopng internal identifier of the local network subnet';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'CIDR notation or user-defined name of the network (e.g. 192.168.1.0/24)';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alias` COMMENT 'User-defined alias for the network';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

DROP TABLE IF EXISTS `engaged_network_alerts`;
@
CREATE TABLE `engaged_network_alerts` (
`rowid` UUID,
`local_network_id` UInt16,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`name` String,
`alias` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = Memory;
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'In-memory table holding currently active (engaged) network/subnet alerts. Rows are inserted when an alert fires and removed when resolved. Merged with network_alerts in network_alerts_view.';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `local_network_id` COMMENT 'ntopng internal identifier of the local network subnet';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'CIDR notation or user-defined name of the network (e.g. 192.168.1.0/24)';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alias` COMMENT 'User-defined alias for the network';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `engaged_network_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

CREATE TABLE IF NOT EXISTS `as_alerts` ON CLUSTER '$CLUSTER' (
`rowid` UUID,
`asn` UInt32,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`name` String,
`alias` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Historical alerts associated with Autonomous Systems (identified by ASN). See engaged_as_alerts for currently-firing alerts and as_alerts_view to query both together.';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `asn` COMMENT 'Autonomous System Number that triggered the alert';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'AS name/description (from WHOIS or user configuration)';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alias` COMMENT 'User-defined alias for this AS';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

DROP TABLE IF EXISTS `engaged_as_alerts`;
@
CREATE TABLE `engaged_as_alerts` (
`rowid` UUID,
`asn` UInt32,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`name` String,
`alias` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = Memory;
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'In-memory table holding currently active (engaged) Autonomous System alerts. Rows are inserted when an alert fires and removed when resolved. Merged with as_alerts in as_alerts_view.';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `asn` COMMENT 'Autonomous System Number that triggered the alert';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'AS name/description (from WHOIS or user configuration)';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alias` COMMENT 'User-defined alias for this AS';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `engaged_as_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

CREATE TABLE IF NOT EXISTS `interface_alerts` ON CLUSTER '$CLUSTER' (
`rowid` UUID,
`ifid` UInt8,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`subtype` String,
`name` String,
`alias` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS require_attention Boolean;
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Historical alerts associated with monitored network interfaces. See engaged_interface_alerts for currently-firing alerts and interface_alerts_view to query both together.';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ifid` COMMENT 'ntopng internal interface index';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `subtype` COMMENT 'Alert sub-type string providing additional context';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'Interface name (e.g. eth0, wlan0)';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alias` COMMENT 'User-defined alias for the interface';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

DROP TABLE IF EXISTS `engaged_interface_alerts`;
@
CREATE TABLE `engaged_interface_alerts` (
`rowid` UUID,
`ifid` UInt8,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`subtype` String,
`name` String,
`alias` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = Memory;
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'In-memory table holding currently active (engaged) interface alerts. Rows are inserted when an alert fires and removed when resolved. Merged with interface_alerts in interface_alerts_view.';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ifid` COMMENT 'ntopng internal interface index';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `subtype` COMMENT 'Alert sub-type string providing additional context';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'Interface name (e.g. eth0, wlan0)';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alias` COMMENT 'User-defined alias for the interface';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `engaged_interface_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

CREATE TABLE IF NOT EXISTS `user_alerts` ON CLUSTER '$CLUSTER' (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`user` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS require_attention Boolean;
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Historical alerts associated with ntopng-managed users. See engaged_user_alerts for currently-firing alerts and user_alerts_view to query both together.';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user` COMMENT 'ntopng username associated with this alert';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

DROP TABLE IF EXISTS `engaged_user_alerts`;
@
CREATE TABLE `engaged_user_alerts` (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`user` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = Memory;
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'In-memory table holding currently active (engaged) user alerts. Rows are inserted when an alert fires and removed when resolved. Merged with user_alerts in user_alerts_view.';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user` COMMENT 'ntopng username associated with this alert';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `engaged_user_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

CREATE TABLE IF NOT EXISTS `system_alerts` ON CLUSTER '$CLUSTER' (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`name` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(tstamp) ORDER BY (tstamp);
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS alert_category UInt8;
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS require_attention Boolean;
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Historical system-level alerts (e.g. license issues, connectivity failures, internal subsystem events). See engaged_system_alerts for currently-firing alerts and system_alerts_view to query both together.';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'Name of the subsystem or component that generated the alert';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';

@

DROP TABLE IF EXISTS `engaged_system_alerts`;
@
CREATE TABLE `engaged_system_alerts` (
`rowid` UUID,
`alert_id` UInt32,
`alert_status` UInt8,
`interface_id` UInt16 DEFAULT 65535,
`name` String,
`tstamp` DateTime,
`tstamp_end` DateTime,
`severity` UInt8,
`score` UInt16,
`granularity` UInt8,
`counter` UInt32,
`description` String,
`json` String,
`user_label` String,
`user_label_tstamp` DateTime,
`alert_category` UInt8,
`require_attention` Boolean
) ENGINE = Memory;
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'In-memory table holding currently active (engaged) system alerts. Rows are inserted when an alert fires and removed when resolved. Merged with system_alerts in system_alerts_view.';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `rowid` COMMENT 'Unique identifier for this alert row (UUID v4)';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_id` COMMENT 'Alert type identifier (maps to ntopng alert type enum)';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_status` COMMENT 'Alert lifecycle status (0=engaged/active, 1=released/archived)';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `interface_id` COMMENT 'ntopng interface identifier; 65535 means system/global scope';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'Name of the subsystem or component that generated the alert';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp` COMMENT 'Timestamp when the alert was first triggered (alert start time)';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `tstamp_end` COMMENT 'Timestamp when the alert was resolved (zero/epoch if still active)';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `severity` COMMENT 'Alert severity level (maps to ntopng AlertLevel enum)';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `score` COMMENT 'Numeric risk/impact score associated with this alert';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `granularity` COMMENT 'Periodic check interval that triggered the alert (e.g. 1=1min, 2=5min)';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `counter` COMMENT 'Number of consecutive intervals this alert condition has been detected';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `description` COMMENT 'Human-readable description of the alert';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json` COMMENT 'Additional alert context and metadata as a JSON blob';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label` COMMENT 'User-defined free-text label applied to this alert';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `user_label_tstamp` COMMENT 'Timestamp when user_label was last set';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `alert_category` COMMENT 'Alert category (maps to ntopng AlertCategory enum)';
@
ALTER TABLE `engaged_system_alerts` ON CLUSTER '$CLUSTER' MODIFY COLUMN `require_attention` COMMENT 'True if this alert has been flagged as requiring manual attention';
@

DROP TABLE IF EXISTS `aggregated_flows` ON CLUSTER '$CLUSTER';
@
CREATE TABLE IF NOT EXISTS `hourly_flows` ON CLUSTER '$CLUSTER' (
`FLOW_ID` UInt64,
`IP_PROTOCOL_VERSION` UInt8,
`FIRST_SEEN` DateTime,
`LAST_SEEN` DateTime,
`VLAN_ID` UInt16,
`PACKETS` UInt32,
`TOTAL_BYTES` UInt64,
`SRC2DST_BYTES` UInt64 /* Total */,
`DST2SRC_BYTES` UInt64 /* Total */,
`SCORE` UInt16 /* Total score */,
`PROTOCOL` UInt8,
`IPV4_SRC_ADDR` UInt32,
`IPV6_SRC_ADDR` IPv6,
`IPV4_DST_ADDR` UInt32,
`IPV6_DST_ADDR` IPv6,
`IP_DST_PORT` UInt16,
`L7_PROTO` UInt16,
`L7_PROTO_MASTER` UInt16,
`NUM_FLOWS` UInt32 /* Total number of flows that have been aggregated */,
`FLOW_RISK` UInt64 /* OS of flow risk */,
`SRC_MAC` UInt64,
`DST_MAC` UInt64,
`PROBE_IP` IPv6,
`EXPORTER_SITE` UInt16,
`NTOPNG_INSTANCE_NAME` String,
`SRC_COUNTRY_CODE` UInt16,
`DST_COUNTRY_CODE` UInt16,
`SRC_ASN` UInt32,
`DST_ASN` UInt32,
`INPUT_SNMP` UInt32,
`OUTPUT_SNMP` UInt32,
`SRC_NETWORK_ID` UInt32,
`DST_NETWORK_ID` UInt32,
`SRC_LABEL` String,
`DST_LABEL` String,
`INTERFACE_ID` UInt16,
`CLIENT_LOCATION` UInt8,
`SERVER_LOCATION` UInt8
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(FIRST_SEEN) ORDER BY (FIRST_SEEN, IPV4_SRC_ADDR, IPV4_DST_ADDR);
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS SRC_LABEL String;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS DST_LABEL String;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS INTERFACE_ID UInt16;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS CLIENT_LOCATION UInt8;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS SERVER_LOCATION UInt8;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS L7_CATEGORY UInt16;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC_HOST_POOL_ID` UInt16;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST_HOST_POOL_ID` UInt16;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC2DST_PACKETS` UInt32;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST2SRC_PACKETS` UInt32;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `EXPORTER_SITE` UInt16;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `PROBE_IP` IPv6;
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Hourly aggregated flow summaries. Multiple raw flows sharing the same 5-tuple are collapsed into one row per hour with summed byte/packet counters and OR-ed risk bitmaps. Used for long-term trend analysis and reduced-resolution historical queries.';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `FLOW_ID` COMMENT 'Unique flow identifier assigned by ntopng';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IP_PROTOCOL_VERSION` COMMENT 'IP version: 4 for IPv4, 6 for IPv6';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `FIRST_SEEN` COMMENT 'Timestamp of the first packet of the flow';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `LAST_SEEN` COMMENT 'Timestamp of the last packet of the flow';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `VLAN_ID` COMMENT '802.1Q VLAN tag (0 if untagged)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PACKETS` COMMENT 'Total packet count in both directions';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `TOTAL_BYTES` COMMENT 'Total bytes transferred in both directions';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC2DST_BYTES` COMMENT 'Bytes sent from client (source) to server (destination)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST2SRC_BYTES` COMMENT 'Bytes sent from server (destination) to client (source)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SCORE` COMMENT 'Composite flow risk/security score';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PROTOCOL` COMMENT 'IP transport protocol number (6=TCP, 17=UDP, 1=ICMP, etc.)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IPV4_SRC_ADDR` COMMENT 'Source IPv4 address as a 32-bit integer; 0 for IPv6 flows';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IPV6_SRC_ADDR` COMMENT 'Source IPv6 address; all-zeros for IPv4 flows';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IPV4_DST_ADDR` COMMENT 'Destination IPv4 address as a 32-bit integer; 0 for IPv6 flows';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IPV6_DST_ADDR` COMMENT 'Destination IPv6 address; all-zeros for IPv4 flows';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IP_DST_PORT` COMMENT 'Destination (server) port number';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `L7_PROTO` COMMENT 'nDPI layer-7 application protocol identifier';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `L7_PROTO_MASTER` COMMENT 'nDPI master/carrier protocol ID (e.g. TLS when L7_PROTO is HTTPS)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `NUM_FLOWS` COMMENT 'Number of raw flows aggregated into this hourly summary row';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `FLOW_RISK` COMMENT 'Bitmap of nDPI flow risk flags (each bit represents a distinct risk)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_MAC` COMMENT 'Source MAC address encoded as a 64-bit integer';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_MAC` COMMENT 'Destination MAC address encoded as a 64-bit integer';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PROBE_IP` COMMENT 'IPv4 or IPv6 address of the NetFlow/IPFIX exporter (probe); IPv4 addresses are stored as IPv4-mapped IPv6 (::ffff:a.b.c.d)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `EXPORTER_SITE` COMMENT 'Site/location identifier of the flow exporter';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `NTOPNG_INSTANCE_NAME` COMMENT 'Hostname/name of the ntopng instance that captured this flow';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_COUNTRY_CODE` COMMENT 'Source IP geo-country: two ASCII letters packed into a UInt16 (high byte = first letter)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_COUNTRY_CODE` COMMENT 'Destination IP geo-country: two ASCII letters packed into a UInt16 (high byte = first letter)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_ASN` COMMENT 'Autonomous System Number of the source IP';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_ASN` COMMENT 'Autonomous System Number of the destination IP';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `INPUT_SNMP` COMMENT 'SNMP input interface index exported via NetFlow/IPFIX';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `OUTPUT_SNMP` COMMENT 'SNMP output interface index exported via NetFlow/IPFIX';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_NETWORK_ID` COMMENT 'ntopng local-network ID for the source IP (0 if not a known local network)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_NETWORK_ID` COMMENT 'ntopng local-network ID for the destination IP (0 if not a known local network)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_LABEL` COMMENT 'Resolved hostname or user-defined label for the source host';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_LABEL` COMMENT 'Resolved hostname or user-defined label for the destination host';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `INTERFACE_ID` COMMENT 'ntopng internal interface identifier';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `CLIENT_LOCATION` COMMENT 'Client host location type (local LAN, remote, etc.)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SERVER_LOCATION` COMMENT 'Server host location type (local LAN, remote, etc.)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `L7_CATEGORY` COMMENT 'nDPI application category identifier';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_HOST_POOL_ID` COMMENT 'ntopng host-pool ID of the source host';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_HOST_POOL_ID` COMMENT 'ntopng host-pool ID of the destination host';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC2DST_PACKETS` COMMENT 'Packet count from client (source) to server (destination)';
@
ALTER TABLE `hourly_flows` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST2SRC_PACKETS` COMMENT 'Packet count from server (destination) to client (source)';

@

/* MITRE */

CREATE TABLE IF NOT EXISTS `mitre_table_info` ON CLUSTER '$CLUSTER' (
`ALERT_ID` UInt16,
`ENTITY_ID` UInt16,
`TACTIC` UInt16,
`TECHNIQUE` UInt16,
`SUB_TECHNIQUE` UInt16,
`MITRE_ID` String
) ENGINE = ReplicatedReplacingMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PRIMARY KEY (`ALERT_ID`, `ENTITY_ID`) ORDER BY (`ALERT_ID`, `ENTITY_ID`);
@
ALTER TABLE `mitre_table_info` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Mapping of ntopng alert IDs and entity types to MITRE ATT&CK tactics, techniques, and sub-techniques. Joined by host_alerts_view and flow_alerts_view to enrich alert rows with ATT&CK context.';
@
ALTER TABLE `mitre_table_info` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ALERT_ID` COMMENT 'ntopng alert type ID that maps to this MITRE entry';
@
ALTER TABLE `mitre_table_info` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ENTITY_ID` COMMENT 'ntopng entity type ID (e.g. 1=host, 4=flow) for this mapping';
@
ALTER TABLE `mitre_table_info` ON CLUSTER '$CLUSTER' MODIFY COLUMN `TACTIC` COMMENT 'MITRE ATT&CK tactic identifier';
@
ALTER TABLE `mitre_table_info` ON CLUSTER '$CLUSTER' MODIFY COLUMN `TECHNIQUE` COMMENT 'MITRE ATT&CK technique identifier';
@
ALTER TABLE `mitre_table_info` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SUB_TECHNIQUE` COMMENT 'MITRE ATT&CK sub-technique identifier (0 if none)';
@
ALTER TABLE `mitre_table_info` ON CLUSTER '$CLUSTER' MODIFY COLUMN `MITRE_ID` COMMENT 'MITRE ATT&CK ID string (e.g. T1046, T1595.002)';

@

/* L7 PROTOCOLS */

CREATE TABLE IF NOT EXISTS `l7_protocols` ON CLUSTER '$CLUSTER' (
`PROTO_ID` UInt16,
`PROTO_NAME` String,
`CATEGORY_ID` UInt16,
`CATEGORY_NAME` String,
`BREED` String
) ENGINE = ReplicatedReplacingMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PRIMARY KEY (`PROTO_ID`) ORDER BY (`PROTO_ID`);
@
ALTER TABLE `l7_protocols` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Static lookup table mapping nDPI protocol IDs to their human-readable names, categories, and breeds. Populated at ntopng startup and used to enrich flow queries with application-layer protocol labels.';
@
ALTER TABLE `l7_protocols` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PROTO_ID` COMMENT 'nDPI application protocol identifier, matches L7_PROTO and L7_PROTO_MASTER in the flows table';
@
ALTER TABLE `l7_protocols` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PROTO_NAME` COMMENT 'Human-readable nDPI protocol name (e.g. TLS, HTTP, DNS)';
@
ALTER TABLE `l7_protocols` ON CLUSTER '$CLUSTER' MODIFY COLUMN `CATEGORY_ID` COMMENT 'nDPI protocol category identifier';
@
ALTER TABLE `l7_protocols` ON CLUSTER '$CLUSTER' MODIFY COLUMN `CATEGORY_NAME` COMMENT 'Human-readable nDPI category name (e.g. Web, Streaming, VPN)';
@
ALTER TABLE `l7_protocols` ON CLUSTER '$CLUSTER' MODIFY COLUMN `BREED` COMMENT 'nDPI protocol breed indicating trustworthiness (e.g. Safe, Unsafe, Fun, Unrated)';

@

/* ASSET */

CREATE TABLE IF NOT EXISTS `assets` ON CLUSTER '$CLUSTER' (
`type` String,
`key` String,
`ifid` UInt8,
`ip` String DEFAULT '',
`mac` String,
`vlan` UInt16 DEFAULT 0,
`network` UInt16 DEFAULT 0,
`name` String DEFAULT '',
`device_type` UInt16 DEFAULT 0,
`manufacturer` String DEFAULT '',
`first_seen` DateTime,
`last_seen` DateTime,
`gateway_mac` String DEFAULT '',
`json_info` String DEFAULT '',
`version` UInt64,
`os_type` String DEFAULT '',
`model` String DEFAULT ''
) ENGINE = ReplicatedReplacingMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}', version) PRIMARY KEY (`type`, `key`) ORDER BY (`type`, `key`);
@
ALTER TABLE assets ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `os_type` String;
@
ALTER TABLE assets ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `model` String;
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Network asset inventory: one row per discovered or imported asset (host, MAC address, network device). Uses ReplicatedReplacingMergeTree on version so that re-discovered assets update existing rows rather than creating duplicates. json_info holds additional metadata as a JSON blob.';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `type` COMMENT 'Asset category (e.g. host, mac, network_device)';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `key` COMMENT 'Unique asset key within its type (e.g. IP address, MAC address)';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ifid` COMMENT 'ntopng interface on which this asset was observed';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ip` COMMENT 'IP address of the asset (empty if not applicable)';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `mac` COMMENT 'MAC address of the asset';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `vlan` COMMENT 'VLAN on which the asset was observed (0 if untagged)';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `network` COMMENT 'ntopng local-network ID the asset belongs to';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `name` COMMENT 'Resolved hostname or user-defined name';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `device_type` COMMENT 'Device category/type (maps to ntopng DeviceType enum)';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `manufacturer` COMMENT 'Hardware manufacturer derived from MAC OUI lookup';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `first_seen` COMMENT 'Timestamp when this asset was first observed by ntopng';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `last_seen` COMMENT 'Timestamp of the most recent observation of this asset';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `gateway_mac` COMMENT 'MAC address of the gateway used to reach this asset';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `json_info` COMMENT 'Additional asset metadata as a JSON blob (OS info, open ports, etc.)';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `version` COMMENT 'Monotonically increasing version counter used by ReplacingMergeTree for deduplication';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `os_type` COMMENT 'Operating system type detected for this asset';
@
ALTER TABLE `assets` ON CLUSTER '$CLUSTER' MODIFY COLUMN `model` COMMENT 'Hardware model string for this asset';

@

/* VIEWS */

DROP VIEW IF EXISTS `active_monitoring_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `active_monitoring_alerts_view` ON CLUSTER '$CLUSTER' AS
SELECT * FROM `active_monitoring_alerts`
UNION ALL
SELECT * FROM `engaged_active_monitoring_alerts`

@

DROP VIEW IF EXISTS `mac_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `mac_alerts_view` ON CLUSTER '$CLUSTER' AS
SELECT * FROM `mac_alerts`
UNION ALL
SELECT * FROM `engaged_mac_alerts`

@

DROP VIEW IF EXISTS `snmp_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `snmp_alerts_view` ON CLUSTER '$CLUSTER' AS
SELECT * FROM `snmp_alerts`
UNION ALL
SELECT * FROM `engaged_snmp_alerts`

@

DROP VIEW IF EXISTS `network_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `network_alerts_view` ON CLUSTER '$CLUSTER' AS
SELECT * FROM `network_alerts`
UNION ALL
SELECT * FROM `engaged_network_alerts`

@

DROP VIEW IF EXISTS `as_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `as_alerts_view` ON CLUSTER '$CLUSTER' AS
SELECT * FROM `as_alerts`
UNION ALL
SELECT * FROM `engaged_as_alerts`

@

DROP VIEW IF EXISTS `interface_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `interface_alerts_view` ON CLUSTER '$CLUSTER' AS
SELECT * FROM `interface_alerts`
UNION ALL
SELECT * FROM `engaged_interface_alerts`

@

DROP VIEW IF EXISTS `user_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `user_alerts_view` ON CLUSTER '$CLUSTER' AS
SELECT * FROM `user_alerts`
UNION ALL
SELECT * FROM `engaged_user_alerts`

@

DROP VIEW IF EXISTS `system_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `system_alerts_view` ON CLUSTER '$CLUSTER' AS
SELECT * FROM `system_alerts`
UNION ALL
SELECT * FROM `engaged_system_alerts`

@

DROP VIEW IF EXISTS `host_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `host_alerts_view` ON CLUSTER '$CLUSTER' AS
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
    ha.tags_map,
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

DROP TABLE IF EXISTS `flow_alerts` ON CLUSTER '$CLUSTER';
@
DROP VIEW IF EXISTS `flow_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `flow_alerts_view` ON CLUSTER '$CLUSTER' AS
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
    f.TAGS_MAP AS tags_map,
    f.SRC_TAGS_MAP AS src_tags_map,
    f.DST_TAGS_MAP AS dst_tags_map,
    f.INFO AS info,
    f.PROBE_IP AS probe_ip,
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

DROP VIEW IF EXISTS `all_alerts_view` ON CLUSTER '$CLUSTER';
@
CREATE VIEW IF NOT EXISTS `all_alerts_view` ON CLUSTER '$CLUSTER' AS
SELECT 8 entity_id, interface_id, alert_id, alert_status, require_attention, tstamp, tstamp_end, severity, score, alert_category FROM `active_monitoring_alerts_view`
UNION ALL
SELECT 4 entity_id, INTERFACE_ID AS interface_id, STATUS AS alert_id, 0 AS alert_status, REQUIRE_ATTENTION AS require_attention, FIRST_SEEN AS tstamp, LAST_SEEN AS tstamp_end, SEVERITY AS severity, SCORE AS score, ALERT_CATEGORY AS alert_category FROM `flows` WHERE (STATUS != 0 AND IS_ALERT_DELETED != 1)
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

CREATE TABLE IF NOT EXISTS `hourly_asn` ON CLUSTER '$CLUSTER' (
`ID` UInt64,
`NTOPNG_INSTANCE_NAME` String,
`INTERFACE_ID` UInt16,
`IP_PROTOCOL_VERSION` UInt8,
`FIRST_SEEN` DateTime,
`LAST_SEEN` DateTime,
`SRC2DST_BYTES` UInt64,
`DST2SRC_BYTES` UInt64,
`TOTAL_BYTES` UInt64,
`SRC2DST_PACKETS` UInt32,
`DST2SRC_PACKETS` UInt32,
`SRC_ASN` UInt32,
`DST_ASN` UInt32,
`SRC_PEER_ASN` UInt32,
`DST_PEER_ASN` UInt32,
`PROBE_IP` IPv6,
`INPUT_SNMP` UInt32,
`OUTPUT_SNMP` UInt32,
`SRC_SITE_ID` UInt16,
`DST_SITE_ID` UInt16
) ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}') PARTITION BY toYYYYMMDD(FIRST_SEEN) ORDER BY (FIRST_SEEN, SRC_ASN, DST_ASN);
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS TOTAL_BYTES UInt64;
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `PROBE_IP` IPv6;
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `SRC_SITE_ID` UInt16;
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `DST_SITE_ID` UInt16;
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COMMENT 'Hourly aggregated traffic statistics per source/destination ASN pair. Used for autonomous-system level traffic analysis and BGP peer analytics. Partitioned by day on FIRST_SEEN.';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `ID` COMMENT 'Unique row identifier';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `NTOPNG_INSTANCE_NAME` COMMENT 'Name of the ntopng instance that generated this record';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `INTERFACE_ID` COMMENT 'ntopng interface identifier on which this traffic was observed';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `IP_PROTOCOL_VERSION` COMMENT 'IP version: 4 for IPv4, 6 for IPv6';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `FIRST_SEEN` COMMENT 'Start of the one-hour aggregation window';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `LAST_SEEN` COMMENT 'End of the one-hour aggregation window';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC2DST_BYTES` COMMENT 'Bytes from source ASN to destination ASN in this hour';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST2SRC_BYTES` COMMENT 'Bytes from destination ASN to source ASN in this hour';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `TOTAL_BYTES` COMMENT 'Total bytes between the two ASNs in this hour';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC2DST_PACKETS` COMMENT 'Packets from source ASN to destination ASN in this hour';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST2SRC_PACKETS` COMMENT 'Packets from destination ASN to source ASN in this hour';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_ASN` COMMENT 'Autonomous System Number of the source';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_ASN` COMMENT 'Autonomous System Number of the destination';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_PEER_ASN` COMMENT 'BGP peer ASN upstream of the source (EXPORTER_IPV4_ADDRESS)';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_PEER_ASN` COMMENT 'BGP peer ASN upstream of the destination';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `PROBE_IP` COMMENT 'IPv4 or IPv6 address of the NetFlow/IPFIX exporter; IPv4 addresses are stored as IPv4-mapped IPv6 (::ffff:a.b.c.d)';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `INPUT_SNMP` COMMENT 'SNMP input interface index from NetFlow/IPFIX';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `OUTPUT_SNMP` COMMENT 'SNMP output interface index from NetFlow/IPFIX';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `SRC_SITE_ID` COMMENT 'ntopng site ID associated with the source network (0 if none)';
@
ALTER TABLE `hourly_asn` ON CLUSTER '$CLUSTER' MODIFY COLUMN `DST_SITE_ID` COMMENT 'ntopng site ID associated with the destination network (0 if none)';

@

/* AS data (local, non replicated) populated on startup */
CREATE TABLE IF NOT EXISTS `asn_info` (
  `asn`          UInt32,
  `handle`       String,
  `description`  String,
  `country_code` String
) ENGINE = ReplacingMergeTree()
  PRIMARY KEY (asn)
  ORDER BY (asn);
@
ALTER TABLE `asn_info` MODIFY COMMENT 'AS (Autonomous System) reference data loaded from geoip/as.csv on startup. Maps ASN to handle, description, and ISO 3166-1 country code. Refreshed on every ntopng startup via TRUNCATE + bulk INSERT.';
@
ALTER TABLE `asn_info` MODIFY COLUMN `asn` COMMENT 'Autonomous System Number (matches flows.SRC_ASN / DST_ASN)';
@
ALTER TABLE `asn_info` MODIFY COLUMN `handle` COMMENT 'BGP handle / RIR registry object name for this AS (e.g. LVLT-1)';
@
ALTER TABLE `asn_info` MODIFY COLUMN `description` COMMENT 'Human-readable organization name for this AS';
@
ALTER TABLE `asn_info` MODIFY COLUMN `country_code` COMMENT 'ISO 3166-1 alpha-2 country code of the AS registrant';
