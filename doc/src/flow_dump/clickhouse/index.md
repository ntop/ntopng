---
title: "ClickHouse (Flow Dump)"
description: "ntopng (Enterprise M or better license is required) for using ClickHouse to store historical flows and alerts. Enterprise XL instead is required for using..."
outline: [2, 3]
lastUpdated: 2026-01-19T08:51:19+01:00
---

<a id="clickhouse"></a>

# ClickHouse (Flow Dump) {#clickhouse-flow-dump}

ntopng (Enterprise M or better license is required) for using ClickHouse to store historical flows and alerts. Enterprise XL instead is required for using aggregated flow and other advanced features.

::: warning
ClickHouse support is not available on Windows.
:::

- [Installation](/flow_dump/clickhouse/installation.md)
  - [FreeBSD Notes](/flow_dump/clickhouse/installation.md#freebsd-notes)
  - [Cluster Configuration](/flow_dump/clickhouse/installation.md#cluster-configuration)
  - [ClickHouse Cloud](/flow_dump/clickhouse/installation.md#clickhouse-cloud)
  - [ClickHouse Tuning](/flow_dump/clickhouse/installation.md#clickhouse-tuning)
- [Connect to ClickHouse](/flow_dump/clickhouse/clickhouse.md)
  - [Example](/flow_dump/clickhouse/clickhouse.md#example)
  - [What's Stored in ClickHouse](/flow_dump/clickhouse/clickhouse.md#what-s-stored-in-clickhouse)
  - [TLS Connection](/flow_dump/clickhouse/clickhouse.md#tls-connection)
  - [Securing the Connection in ClickHouse Cloud](/flow_dump/clickhouse/clickhouse.md#securing-the-connection-in-clickhouse-cloud)
  - [Server Certificate Verification](/flow_dump/clickhouse/clickhouse.md#server-certificate-verification)
  - [Mutual TLS (mTLS)](/flow_dump/clickhouse/clickhouse.md#mutual-tls-mtls)
  - [Strict Startup](/flow_dump/clickhouse/clickhouse.md#strict-startup)
- [ClickHouse DB Schema](/flow_dump/clickhouse/clickhouse_schema.md)
- [Historical](/flow_dump/clickhouse/historical_flows.md)
  - [Details](/flow_dump/clickhouse/historical_flows.md#details)
  - [Track Flows](/flow_dump/clickhouse/historical_flows.md#track-flows)
  - [Enabling Flow Dump](/flow_dump/clickhouse/historical_flows.md#enabling-flow-dump)
  - [Custom Queries](/flow_dump/clickhouse/historical_flows.md#custom-queries)
  - [Exporting Flows](/flow_dump/clickhouse/historical_flows.md#exporting-flows)
  - [Data Retention](/flow_dump/clickhouse/historical_flows.md#data-retention)
  - [Hourly Historical Flows](/flow_dump/clickhouse/historical_flows.md#hourly-historical-flows)
  - [Aggregation Preferences](/flow_dump/clickhouse/historical_flows.md#aggregation-preferences)
  - [Replay Historical Flows](/flow_dump/clickhouse/historical_flows.md#replay-historical-flows)
  - [Historical Flows Archive for Compliance](/flow_dump/clickhouse/historical_flows.md#historical-flows-archive-for-compliance)
  - [Benefits](/flow_dump/clickhouse/historical_flows.md#benefits)
  - [Enabling Flow Export](/flow_dump/clickhouse/historical_flows.md#enabling-flow-export)
  - [Default Export Location](/flow_dump/clickhouse/historical_flows.md#default-export-location)
  - [Custom Export Directory](/flow_dump/clickhouse/historical_flows.md#custom-export-directory)
  - [Importing Archived Flow Data](/flow_dump/clickhouse/historical_flows.md#importing-archived-flow-data)
  - [Viewing Imported Data in ntopng](/flow_dump/clickhouse/historical_flows.md#viewing-imported-data-in-ntopng)
  - [Important Notes](/flow_dump/clickhouse/historical_flows.md#important-notes)
- [Traffic Reports](/flow_dump/clickhouse/reports.md)
  - [Save/Open Reports on ntopng](/flow_dump/clickhouse/reports.md#save-open-reports-on-ntopng)
  - [Backup/Load Reports Locally](/flow_dump/clickhouse/reports.md#backup-load-reports-locally)
  - [Print Report (PDF)](/flow_dump/clickhouse/reports.md#print-report-pdf)
  - [Automatic Reports and Notifications](/flow_dump/clickhouse/reports.md#automatic-reports-and-notifications)
  - [Data Retention](/flow_dump/clickhouse/reports.md#data-retention)
  - [Reports Editor](/flow_dump/clickhouse/reports.md#reports-editor)

