---
title: "Flows Dump (ClickHouse)"
description: "Ntopng supports flows dump towards multiple downstream databases, namely ClickHouse, Elasticsearch and Syslog. Flows dump is enabled using option -F."
outline: [2, 3]
lastUpdated: 2026-08-27T14:05:53+00:00
---

<a id="flowsdump"></a>

# Flows Dump (ClickHouse) {#flows-dump-clickhouse}

Ntopng supports flows dump towards multiple downstream databases, namely ClickHouse, Elasticsearch and Syslog. Flows dump is enabled using option `-F`.

::: info
ClickHouse support is the recommended database backend used to dump flows and alerts.
:::

When flows dump is enabled, a new `Flow Dump Settings` tab appears in the preferences.

![Flows Dump Settings](../img/advanced_features_flows_dump_setting.png "Flows Dump Settings")

`Flow Dump Settings` entries are:

- `Flows Dump`: to toggle the dump of flows during the execution of ntopng. Flows dump can be turned on or off using this toggle. Turning flows dump off may be useful when the destination downstream database is running out of space, for debug purposes, or when the user only wants alerts stored in [Elasticsearch](/user_interface/shared/alerts/available_endpoints.md#elasticsearchalerts).
- `Tiny Flows Dump`: to toggle the dump of tiny flows. Tiny flows are small flows, that is, flows totalling less than a certain configurable number of packets or bytes. Excluding tiny flows from the dump is an effective strategy to reduce the number of dumped flows. This reduction is mostly effective when dumped flows are used to do analyses based on the volume. It is not recommended to use this option when dumped flows are used for security analyses.
- `ElasticSearch Flow Dump Frequency`: is the frequency of the flow dump towards ElasticSearch.

These settings are effective for all databases.

- [ClickHouse (Flow Dump)](/flow_dump/clickhouse/index.md)
  - [Installation](/flow_dump/clickhouse/installation.md)
  - [Connect to ClickHouse](/flow_dump/clickhouse/clickhouse.md)
  - [ClickHouse DB Schema](/flow_dump/clickhouse/clickhouse_schema.md)
  - [Historical](/flow_dump/clickhouse/historical_flows.md)
  - [Traffic Reports](/flow_dump/clickhouse/reports.md)
- [Kafka](/flow_dump/kafka/index.md)
  - [Exporting Flows to Kafka](/flow_dump/kafka/export_flows.md)
  - [Collecting nProbe Flows Using Kafka](/flow_dump/kafka/collect_flows.md)
  - [Sending Messages to Kafka](/flow_dump/kafka/send_kafka_messages.md)
- [Syslog](/flow_dump/syslog/index.md)

