---
title: "ClickHouse"
description: "ntopng features ClickHouse to export flows to ClickHouse. Enabling the export into ClickHouse Database is going to make the Historical Flow Explorer page..."
outline: [2, 3]
lastUpdated: 2026-11-03T10:58:14+01:00
---

<a id="clickhouse"></a>

# ClickHouse {#clickhouse}

ntopng features ClickHouse to export flows to [ClickHouse](https://clickhouse.com/). Enabling the export into ClickHouse Database is going to make the Historical Flow Explorer page available.

::: info
ClickHouse export is available only with Enterprise license. See [Connect to ClickHouse](/flow_dump/clickhouse/clickhouse.md) for how to configure ClickHouse support in ntopng.
:::

![The ClickHouse Monitor Home](../../../img/clickhouse_monitor_home.png "The ClickHouse Monitor Home")

The page shows a *Status* card, refreshed every 10 seconds, with the following items:

- `Version`: The version of the ClickHouse server.
- `Health`: A badge which is either green or red. The badge is green when ntopng can query ClickHouse, red when it cannot: in this case expect the historical pages to malfunction.
- `Tables Size`: Disk space used by the flows table, the hourly flows table and the alert tables, with a bar comparing them. Flow alerts are counted in the flows table size.
- `Table Records`: The number of flows and hourly flows stored, with the average space used by one record, and the number of alerts (flow alerts excluded).
- `Last Errors`: The last errors reported by ClickHouse, useful to check if something went wrong while storing or querying the flows.
