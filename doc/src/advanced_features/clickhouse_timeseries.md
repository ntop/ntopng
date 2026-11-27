---
title: "ClickHouse Timeseries"
description: "This page describes the ClickHouse timeseries driver in detail. For a high-level overview of"
outline: [2, 3]
lastUpdated: 2026-03-16T11:33:21+01:00
---

<a id="clickhousetimeseriesadvanced"></a>

# ClickHouse Timeseries {#clickhouse-timeseries}

This page describes the ClickHouse timeseries driver in detail. For a high-level overview of
all timeseries drivers, see [Timeseries](/basic_concepts/timeseries.md#basicconceptstimeseries).

::: info
ClickHouse timeseries support requires an **Enterprise M** or better license and the
`HAVE_CLICKHOUSE` compile-time flag. It is not available on Windows.
:::

## Overview {#overview}

The ClickHouse timeseries driver stores all traffic metrics produced by ntopng (interface
traffic, per-host statistics, application protocol breakdowns, etc.) in a ClickHouse columnar
database. This provides high write throughput, flexible time-range queries, automatic data
retention via TTL, and optional cluster/cloud deployment.

All timeseries data lands in a single table (`timeseries`) whose rows carry a schema name,
a timestamp, a tag map (key-value pairs used for filtering), and a metric map (the actual
numeric measurements). The driver is a drop-in replacement for the RRD and InfluxDB drivers —
the same ntopng charts and API calls work regardless of which driver is active.

## Configuration {#configuration}

### Deployment Modes {#deployment-modes}

The ClickHouse timeseries driver is selected via the `-F` option, which also configures the
connection parameters. Please check the **Flows Dump** section for configuring ClickHouse.

::: info
The same `-F` flag is used for ClickHouse **flow dump** (historical flows) and ClickHouse
**timeseries**. When `-F clickhouse` (or a variant) is set, both feature sets share the
same ClickHouse server connection and database.
:::

### Timeseries Driver Preference {#timeseries-driver-preference}

The active timeseries driver can also be changed at runtime from the ntopng preferences UI
under *Timeseries* → *Driver*. Setting it to `clickhouse` activates this driver for all new
time-series writes.

### Data Retention {#data-retention}

Retention is controlled by the *Timeseries Data Retention* preference (in days, default 365).
The value is applied as a ClickHouse `TTL` clause on the `timeseries` table. When retention
changes, the table DDL is re-issued with the new TTL and ClickHouse handles background cleanup
automatically — no manual purge is required.

## Database Schema {#database-schema}

### Table Definition {#table-definition}

On first startup (or when the retention period changes), ntopng creates the following table
in the configured ClickHouse database (default: `ntopng`):

```sql
CREATE TABLE IF NOT EXISTS `ntopng`.`timeseries`
(
    `schema_name`  LowCardinality(String),
    `tstamp`       DateTime CODEC(Delta, ZSTD),
    `tags`         Map(LowCardinality(String), String),
    `metrics`      Map(LowCardinality(String), Float64)
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(tstamp)
ORDER BY (schema_name, tstamp)
TTL tstamp + toIntervalDay(<retention_days>)
```

### Column Details {#column-details}

`schema_name` (`LowCardinality(String)`)

: Identifies the type of measurement, e.g. `iface:traffic`, `host:traffic`,
  `interface:ndpi`. Using `LowCardinality` avoids redundant string storage for the small
  set of distinct schema identifiers.

`tstamp` (`DateTime CODEC(Delta, ZSTD)`)

: Unix timestamp of the data point. The Delta codec stores differences between consecutive
  timestamps (reducing entropy for regular time series), then ZSTD compresses the result.

`tags` (`Map(LowCardinality(String), String)`)

: Key-value pairs used to filter and group data. Keys are bounded-cardinality identifiers such
  as `ifid`, `host`, or `protocol`. Values are the corresponding entity identifiers.
  Example: `{'ifid': '0', 'host': '192.168.1.1'}`.

`metrics` (`Map(LowCardinality(String), Float64)`)

: The numeric measurements. Keys are metric names (`bytes`, `packets`, `duration_ms`,
  etc.); values are `Float64` measurements.
  Example: `{'bytes': 1048576.0, 'packets': 1024.0}`.

### Partitioning and Ordering {#partitioning-and-ordering}

Data is partitioned monthly (`toYYYYMM(tstamp)`), which allows ClickHouse to prune entire
partitions when querying a specific time range. Within each partition, rows are sorted by
`(schema_name, tstamp)`, optimising the most common query pattern: filter by schema, scan
a time range.

## Query Behaviour {#query-behaviour}

### Counter vs. Gauge Metrics {#counter-vs-gauge-metrics}

Each timeseries schema declares whether its metrics are *counters* (monotonically increasing
totals, e.g. cumulative bytes) or *gauges* (instantaneous values, e.g. CPU load percentage).

- **Counter** metrics: the driver fetches one extra time bucket before the requested range,
  computes per-bucket deltas using a `lag()` window function, and divides by the bucket
  width to produce rates (e.g., bytes/second).
- **Gauge** metrics: the driver aggregates (`avg`, `max`, or `min`) directly within
  each time bucket.

## Comparison with Other Drivers {#comparison-with-other-drivers}

| Aspect | RRD | InfluxDB | ClickHouse |
|---|---|---|---|
| Storage | Per-entity `.rrd` files | InfluxDB server (line protocol) | Centralised columnar table |
| Write model | Synchronous file write per entity | HTTP line-protocol POST | Async in-memory queue → batch INSERT (TCP) |
| Flush interval | Each periodic activity | Each periodic activity | Every 5 seconds (up to 2 000 rows/batch) |
| Retention model | Fixed RRA archives (1 year total) | Retention policies | TTL clause, configurable in days |
| Top-K queries | Scan many files; slow at scale | InfluxDB continuous queries | Single SQL query; fast at scale |
| Cluster/HA | None (local filesystem) | InfluxDB Enterprise / OSS cluster | ClickHouse native cluster replication |
| License required | Community+ | Community+ | Enterprise M+ |
