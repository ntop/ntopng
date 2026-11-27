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
ntopng drops the daily partitions older than the retention period, so a change of the preference
applies to the data already stored too: no manual purge is required.

## Database Schema {#database-schema}

### Table Definition {#table-definition}

On first startup, ntopng creates the following table in the configured ClickHouse database
(default: `ntopng`):

```sql
CREATE TABLE IF NOT EXISTS `ntopng`.`timeseries`
(
    `schema_name`          LowCardinality(String),
    `ifid`                 Int16,
    `ntopng_instance_name` LowCardinality(String),
    `tstamp`               DateTime CODEC(Delta, ZSTD),
    `tags`                 Map(LowCardinality(String), String),
    `metrics`              Map(LowCardinality(String), Float64),
    `entity`               String
)
ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(tstamp)
ORDER BY (schema_name, ifid, entity, tstamp)
```

### Column Details {#column-details}

`schema_name` (`LowCardinality(String)`)

: Identifies the type of measurement, e.g. `iface:traffic`, `host:traffic`,
  `interface:ndpi`. Using `LowCardinality` avoids redundant string storage for the small
  set of distinct schema identifiers.

`ifid` (`Int16`)

: The interface of the data point, the same value of the `ifid` tag.

`ntopng_instance_name` (`LowCardinality(String)`)

: The name of the ntopng instance that wrote the data point.

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

`entity` (`String`)

: The values of the tags after `ifid`, in the order defined by the schema, separated by the
  `\x1F` character. Example: `192.168.1.1\x1FDNS` for the `host:ndpi` schema
  (host `192.168.1.1`, protocol DNS), empty for the interface schemas.

### Partitioning and Ordering {#partitioning-and-ordering}

Data is partitioned daily (`toYYYYMMDD(tstamp)`), which allows ClickHouse to prune entire
partitions when querying a specific time range. Within each partition, rows are sorted by
`(schema_name, ifid, entity, tstamp)`: the rows of one entity are contiguous, so a chart of a
single host, ASN or device reads only its rows. A query that gives only the first tags of a
schema (e.g. the top protocols of a host) reads only the rows of that prefix of the entity.

### Upgrading a Table Created by an Older Version {#upgrading-a-table-created-by-an-older-version}

A table created by an older version of ntopng is sorted by `(schema_name, ifid, tstamp)`:
a chart of a single entity reads the rows of all the entities of its schema. ntopng adds the
`entity` column to such a table, but ClickHouse cannot change the sort order of an existing
table, so the charts keep reading as before.

To move the table to the new sort order, an administrator clicks *Upgrade at Next Restart* in the
*Timeseries Table Upgrade* notification, then restarts ntopng. At the next startup ntopng:

1. checks that ClickHouse has free disk space for a copy of the table (1.2 times its size);
2. copies the data, one day at a time, to a new table with the new sort order;
3. checks that every row was copied, then exchanges the two tables and drops the old data.

The upgrade can take several minutes (about one minute every 70 million rows): meanwhile the
traffic is not recorded and the GUI is not available, the progress is reported in the ntopng log.
If any step fails, the old table is left unchanged and the notification reports the error. The
exchange of the tables requires the `Atomic` database engine, the ClickHouse default.

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
