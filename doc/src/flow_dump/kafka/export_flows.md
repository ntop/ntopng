---
title: "Exporting Flows to Kafka"
description: "Similar to other export methods such as ClickHouse and Elastic, you can instruct ntopng to export flows to Kakfa using the -F option. The format of this..."
outline: [2, 3]
lastUpdated: 2025-02-12T16:12:50+01:00
---

<a id="kafkaflowexport"></a>

# Exporting Flows to Kafka {#exporting-flows-to-kafka}

Similar to other export methods such as ClickHouse and Elastic, you can instruct ntopng to export flows to Kakfa using the `-F` option. The format of this option is the following

```bash
kafka;[<brokerIP[:<port>]]+;<topic>[;<kafka option>=<value>]+
```

Where

- `<brokerIP[:<port>]` Specifies the address of the kafka broker(s) used by ntopng. You can specify the port or omit it to use the default one. If you have multiple brokers to use, you can use a comma (,) to split them.
- `<topic>` Specifies the Kafka topic name to which ntopng exported flows will be sent to.
- `<options>` You can specify options to be used during kafka connection. You can specify multiple options by splitting them with a comma (,). You can read the whole list of [supported kafka options](https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md) to know what options are supported.

## Example {#example}

Below you can find some examples:

> - Export flows to the topic ntopng_flows to a Kafka broker running on the same host where ntopng runs and listening on the default port (9092). Use: `kafka;127.0.0.1;ntopng_flows`.
> - Export flows to brokers 127.0.0.1:7689, 192.168.1.20:9092 and 192.168.1.2:9091 and compress data (when talking to Kafka) using gzip. Use: `kafka;127.0.0.1:7689,192.168.1.20,192.168.1.2;ntopng_flows;compression.codec=gzip`.
