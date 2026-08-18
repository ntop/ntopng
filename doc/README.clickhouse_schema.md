# ntopng ClickHouse Database Schema

This document describes the ClickHouse database schema used by ntopng to persist flow records, alerts, assets, and related analytical data. The schema is defined in two files that must be kept in sync:

| File | Purpose |
|------|---------|
| `httpdocs/misc/db_schema_clickhouse.sql` | Single-node ClickHouse deployment (uses `MergeTree` family engines) |
| `httpdocs/misc/db_schema_clickhouse_cluster.sql` | Multi-node replicated cluster deployment (uses `ReplicatedMergeTree` / `ReplicatedReplacingMergeTree` engines and `ON CLUSTER '$CLUSTER'` DDL) |

Both files are parsed and executed by ntopng at startup via `pro/src/ClickHouseDB.cpp`. Statements are separated by `@` delimiters rather than standard semicolons to allow ntopng's SQL runner to feed them one at a time. Each file contains both `CREATE TABLE IF NOT EXISTS` statements (idempotent schema bootstrap) and `ALTER TABLE … ADD/MODIFY COLUMN IF NOT EXISTS` statements (idempotent schema migrations for upgrades from older versions).

---

## Table Overview

| Table | Engine | Description |
|-------|--------|-------------|
| [`flows`](#flows) | MergeTree | Per-flow telemetry records |
| [`hourly_flows`](#hourly_flows) | MergeTree | Hourly aggregated flow summaries |
| [`hourly_asn`](#hourly_asn) | MergeTree | Hourly per-ASN traffic statistics |
| [`active_monitoring_alerts`](#alert-tables) | MergeTree | Historical active-monitoring alerts |
| [`host_alerts`](#alert-tables) | MergeTree | Historical host alerts |
| [`mac_alerts`](#alert-tables) | MergeTree | Historical MAC/device alerts |
| [`snmp_alerts`](#alert-tables) | MergeTree | Historical SNMP alerts |
| [`network_alerts`](#alert-tables) | MergeTree | Historical subnet alerts |
| [`as_alerts`](#alert-tables) | MergeTree | Historical Autonomous System alerts |
| [`interface_alerts`](#alert-tables) | MergeTree | Historical interface alerts |
| [`user_alerts`](#alert-tables) | MergeTree | Historical user alerts |
| [`system_alerts`](#alert-tables) | MergeTree | Historical system alerts |
| [`engaged_*_alerts`](#engaged-alert-tables) | Memory | Currently active (engaged) alerts |
| [`vulnerability_scan_data`](#vulnerability_scan_data) | MergeTree | Per-host vulnerability scan results |
| [`vulnerability_scan_report`](#vulnerability_scan_report) | MergeTree | Vulnerability scan summary reports |
| [`mitre_table_info`](#mitre_table_info) | ReplacingMergeTree | MITRE ATT&CK mappings |
| [`assets`](#assets) | ReplacingMergeTree | Network asset inventory |

Views that merge historical and engaged tables are described in the [Views](#views) section.

---

## flows

The central table. Every bidirectional network flow observed by ntopng — whether captured locally or received via NetFlow/sFlow/IPFIX — produces one row. Partitioned by day on `FIRST_SEEN`; ordered by `(FIRST_SEEN, IPV4_SRC_ADDR, IPV4_DST_ADDR)`.

### Key column groups

| Group | Columns |
|-------|---------|
| Identity | `FLOW_ID`, `NTOPNG_INSTANCE_NAME`, `INTERFACE_ID` |
| Timing | `FIRST_SEEN`, `LAST_SEEN` |
| Network 5-tuple | `PROTOCOL`, `IPV4_SRC_ADDR` / `IPV6_SRC_ADDR`, `IP_SRC_PORT`, `IPV4_DST_ADDR` / `IPV6_DST_ADDR`, `IP_DST_PORT` |
| Traffic counters | `PACKETS`, `TOTAL_BYTES`, `SRC2DST_BYTES`, `DST2SRC_BYTES`, `SRC2DST_PACKETS`, `DST2SRC_PACKETS` |
| Layer 7 | `L7_PROTO`, `L7_PROTO_MASTER`, `L7_CATEGORY`, `INFO`, `FLOW_RISK` |
| QoS / latency | `SRC2DST_DSCP`, `DST2SRC_DSCP`, `CLIENT_NW_LATENCY_US`, `SERVER_NW_LATENCY_US`, `QOE_SCORE` |
| Host metadata | `SRC_LABEL`, `DST_LABEL`, `SRC_COUNTRY_CODE`, `DST_COUNTRY_CODE`, `SRC_ASN`, `DST_ASN`, `SRC_PEER_ASN`, `DST_PEER_ASN`, `SRC_MAC`, `DST_MAC` |
| Network topology | `VLAN_ID`, `COMMUNITY_ID`, `OBSERVATION_POINT_ID`, `INTERFACE_ROLE`, `PROBE_IP`, `EXPORTER_SITE`, `NEXT_HOP_IP`, `NEXT_HOP_SITE`, `INPUT_SNMP`, `OUTPUT_SNMP`, `SRC_NETWORK_ID`, `DST_NETWORK_ID` |
| Host pools | `SRC_HOST_POOL_ID`, `DST_HOST_POOL_ID` |
| Process info (eBPF) | `SRC_PROC_NAME`, `DST_PROC_NAME`, `SRC_PROC_USER_NAME`, `DST_PROC_USER_NAME` |
| TCP state | `SRC2DST_TCP_FLAGS`, `DST2SRC_TCP_FLAGS`, `MINOR_CONNECTION_STATE`, `MAJOR_CONNECTION_STATE` |
| Fingerprints | `CLIENT_FINGERPRINT`, `TCP_FINGERPRINT` |
| NAT | `POST_NAT_IPV4_SRC_ADDR`, `POST_NAT_SRC_PORT`, `POST_NAT_IPV4_DST_ADDR`, `POST_NAT_DST_PORT` |
| Wireless | `WLAN_SSID`, `WTP_MAC_ADDRESS` |
| Alert fields | `STATUS`, `SCORE`, `SEVERITY`, `ALERT_STATUS`, `ALERT_CATEGORY`, `ALERT_JSON`, `ALERTS_MAP`, `IS_ALERT_DELETED`, `FLOW_RISK` |
| Threat intel flags | `IS_CLI_ATTACKER`, `IS_CLI_VICTIM`, `IS_CLI_BLACKLISTED`, `IS_SRV_ATTACKER`, `IS_SRV_VICTIM`, `IS_SRV_BLACKLISTED` |
| User annotation | `USER_LABEL`, `USER_LABEL_TSTAMP`, `PROFILE`, `REQUIRE_ATTENTION` |
| Protocol detail | `PROTOCOL_INFO_JSON`, `DOMAIN_NAME` |

> **Note on alert flows**: A flow row doubles as an alert record when `STATUS != 0`. The `flow_alerts_view` filters for these rows and joins them with `mitre_table_info` for ATT&CK enrichment.

> **Country encoding**: `SRC_COUNTRY_CODE` and `DST_COUNTRY_CODE` store two ISO 3166-1 ASCII letters packed into a `UInt16` (high byte = first letter). The `flow_alerts_view` decodes them with `char(bitShiftRight(..., 8), bitAnd(..., 0xFF))`.

---

## hourly_flows

Hourly rollup of the `flows` table. Multiple raw flows sharing the same 5-tuple within an hour are collapsed into one row with summed byte/packet counters. Used for long-term trend analysis and dashboards that do not need per-flow granularity.

Compared to `flows` it omits per-flow alert fields, process info, fingerprints, TCP flags, and NAT columns, and adds:

- `NUM_FLOWS UInt32` — number of raw flows collapsed into this row.

---

## hourly_asn

Hourly aggregated traffic statistics broken down by source/destination ASN pair. Used for AS-level traffic analysis and BGP peer analytics. Partitioned by day on `FIRST_SEEN`; ordered by `(FIRST_SEEN, SRC_ASN, DST_ASN)`.

Columns include `SRC_ASN`, `DST_ASN`, `SRC_PEER_ASN`, `DST_PEER_ASN`, directional byte/packet counters, `PROBE_IP`, and SNMP interface indices.

---

## Alert Tables

ntopng models nine entity types that can generate alerts. Each entity type has a pair of tables:

| Historical table | Engaged (in-memory) table | View |
|-----------------|--------------------------|------|
| `active_monitoring_alerts` | `engaged_active_monitoring_alerts` | `active_monitoring_alerts_view` |
| `host_alerts` | `engaged_host_alerts` | `host_alerts_view` |
| `mac_alerts` | `engaged_mac_alerts` | `mac_alerts_view` |
| `snmp_alerts` | `engaged_snmp_alerts` | `snmp_alerts_view` |
| `network_alerts` | `engaged_network_alerts` | `network_alerts_view` |
| `as_alerts` | `engaged_as_alerts` | `as_alerts_view` |
| `interface_alerts` | `engaged_interface_alerts` | `interface_alerts_view` |
| `user_alerts` | `engaged_user_alerts` | `user_alerts_view` |
| `system_alerts` | `engaged_system_alerts` | `system_alerts_view` |

### Common columns (all alert tables)

| Column | Type | Description |
|--------|------|-------------|
| `rowid` | UUID | Unique row identifier |
| `alert_id` | UInt32 | Alert type (maps to ntopng alert type enum) |
| `alert_status` | UInt8 | Lifecycle state: 0 = engaged/active, 1 = released/archived |
| `interface_id` | UInt16 | ntopng interface; 65535 = system/global scope |
| `tstamp` | DateTime | Alert start time |
| `tstamp_end` | DateTime | Alert resolution time (epoch zero if still active) |
| `severity` | UInt8 | Severity level (maps to `AlertLevel` enum) |
| `score` | UInt16 | Numeric risk/impact score |
| `granularity` | UInt8 | Check interval that triggered the alert (1=1min, 2=5min, …) |
| `counter` | UInt32 | Consecutive detection count |
| `description` | String | Human-readable description |
| `json` | String | Additional context as JSON |
| `user_label` | String | User-defined free-text label |
| `user_label_tstamp` | DateTime | When `user_label` was last set |
| `alert_category` | UInt8 | Category (maps to `AlertCategory` enum) |
| `require_attention` | Boolean | Flagged for manual review |

### Entity-specific columns

**`active_monitoring_alerts`**: `resolved_ip`, `resolved_name`, `measurement`, `measure_threshold`, `measure_value`

**`host_alerts`**: `ip_version`, `ip`, `vlan_id`, `name`, `is_attacker`, `is_victim`, `is_client`, `is_server`, `host_pool_id`, `network`, `country`

**`mac_alerts`**: `address`, `device_type`, `name`, `is_attacker`, `is_victim`

**`snmp_alerts`**: `ip`, `port` (ifIndex), `name`, `port_name`

**`network_alerts`**: `local_network_id`, `name`, `alias`

**`as_alerts`**: `asn`, `name`, `alias`

**`interface_alerts`**: `ifid`, `subtype`, `name`, `alias`

**`user_alerts`**: `user`

**`system_alerts`**: `name`

---

## Engaged Alert Tables

Each `engaged_*_alerts` table uses the `Memory` engine and holds only the currently-firing (engaged) alerts. Rows are inserted when an alert fires and deleted when it resolves. They have identical column schemas to their MergeTree counterparts.

These tables are dropped and recreated on every ntopng startup to prevent stale engaged alerts from persisting across restarts.

---

## vulnerability_scan_data

Stores raw per-host vulnerability scan results produced by the ntopng Vulnerability Scanner (VS) module. Partitioned by day on `LAST_SCAN`; ordered by `(LAST_SCAN, HOST, SCAN_TYPE)`.

| Column | Description |
|--------|-------------|
| `HOST` | IP address or hostname of the scanned target |
| `SCAN_TYPE` | Scan type (e.g. `nmap`, `openvas`) |
| `LAST_SCAN` | Timestamp of the most recent scan |
| `JSON_INFO` | Full scan results as JSON |
| `VS_RESULT_FILE` | Path to the raw result file on disk |

---

## vulnerability_scan_report

One row per completed vulnerability scan report. Partitioned by day on `REPORT_DATE`.

| Column | Description |
|--------|-------------|
| `REPORT_NAME` | User-defined report name |
| `REPORT_DATE` | Report generation timestamp |
| `REPORT_JSON_INFO` | Full report metadata as JSON |
| `NUM_SCANNED_HOSTS` | Hosts scanned |
| `NUM_CVES` | No more used |
| `NUM_TCP_PORTS` | Open TCP ports found |
| `NUM_UDP_PORTS` | Open UDP ports found |

---

## mitre_table_info

Maps ntopng alert type IDs and entity type IDs to MITRE ATT&CK framework entries. Uses `ReplacingMergeTree` keyed on `(ALERT_ID, ENTITY_ID)` to prevent duplicates.

| Column | Description |
|--------|-------------|
| `ALERT_ID` | ntopng alert type ID |
| `ENTITY_ID` | ntopng entity type ID (1=host, 4=flow, …) |
| `TACTIC` | MITRE ATT&CK tactic identifier |
| `TECHNIQUE` | MITRE ATT&CK technique identifier |
| `SUB_TECHNIQUE` | Sub-technique identifier (0 if none) |
| `MITRE_ID` | ATT&CK ID string (e.g. `T1046`, `T1595.002`) |

This table is joined by `host_alerts_view` and `flow_alerts_view` to surface MITRE context alongside alert data.

---

## assets

Network asset inventory. One row per discovered or imported asset (host, MAC address, network device). Uses `ReplacingMergeTree(version)` so that re-observations update existing rows rather than creating duplicates. Primary key is `(type, key)`.

| Column | Description |
|--------|-------------|
| `type` | Asset category (e.g. `host`, `mac`, `network_device`) |
| `key` | Unique key within the type (IP address, MAC address, etc.) |
| `ifid` | ntopng interface where the asset was observed |
| `ip` | IP address (empty if not applicable) |
| `mac` | MAC address |
| `vlan` | VLAN (0 if untagged) |
| `network` | ntopng local-network ID |
| `name` | Resolved hostname or user-defined name |
| `device_type` | Device category (maps to `DeviceType` enum) |
| `manufacturer` | Manufacturer from MAC OUI lookup |
| `first_seen` | First observation timestamp |
| `last_seen` | Most recent observation timestamp |
| `gateway_mac` | MAC address of the gateway used to reach this asset |
| `json_info` | Additional metadata as JSON (OS info, open ports, etc.) |
| `version` | Monotonic counter used by `ReplacingMergeTree` for deduplication |
| `os_type` | Detected operating system type |
| `model` | Hardware model string |

---

## Views

Views are recreated on each ntopng startup (`DROP VIEW IF EXISTS` + `CREATE VIEW IF NOT EXISTS`).

### Per-entity alert views

Each `*_alerts_view` is a `UNION ALL` of its historical MergeTree table and its in-memory engaged counterpart, providing a unified query surface for both resolved and currently-active alerts:

```sql
-- example
SELECT * FROM host_alerts
UNION ALL
SELECT * FROM engaged_host_alerts
```

**`host_alerts_view`** additionally `LEFT JOIN`s `mitre_table_info` (on `ENTITY_ID = 1`) to attach ATT&CK tactic/technique columns.

### flow_alerts_view

Selects only alert flows from the `flows` table (`STATUS != 0 AND IS_ALERT_DELETED != 1`), renames columns to a friendlier lowercase schema (e.g. `IPV4_SRC_ADDR` → resolved `cli_ip` string), and `LEFT JOIN`s `mitre_table_info` (on `ENTITY_ID = 4`).

### all_alerts_view

A single `UNION ALL` across all per-entity alert views plus alert flows, exposing a minimal common schema: `entity_id`, `interface_id`, `alert_id`, `alert_status`, `require_attention`, `tstamp`, `tstamp_end`, `severity`, `score`, `alert_category`. Entity ID values:

| `entity_id` | Source |
|-------------|--------|
| 0 | `interface_alerts_view` |
| 1 | `host_alerts_view` |
| 2 | `network_alerts_view` |
| 3 | `snmp_alerts_view` |
| 4 | `flows` (alert rows) |
| 5 | `mac_alerts_view` |
| 7 | `user_alerts_view` |
| 8 | `active_monitoring_alerts_view` |
| 9 | `system_alerts_view` |
| 10 | `as_alerts_view` |

---

## Schema Versioning and Migrations

The schema files follow an additive migration pattern: new columns are added with `ALTER TABLE … ADD COLUMN IF NOT EXISTS` statements appended at the end of the file. Columns are never removed via migration (only via explicit `DROP COLUMN IF EXISTS` for columns that were renamed or replaced). This ensures forward compatibility — an older ntopng version can read a database created by a newer version without crashing, it will simply ignore unknown columns.

When adding a new column to the schema:
1. Add it to the `CREATE TABLE` statement.
2. Add a corresponding `ALTER TABLE … ADD COLUMN IF NOT EXISTS` migration statement.
3. Keep `db_schema_clickhouse.sql` and `db_schema_clickhouse_cluster.sql` in sync.
4. Also update `pro/include/FlowsTable.h`, `pro/src/ClickHouseDB.cpp`, `scripts/lua/modules/tag_utils.lua`, and `scripts/lua/modules/historical_flow_utils.lua` as noted in the header comment of the schema files.
