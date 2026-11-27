---
title: "Collecting nProbe Flows Using Kafka"
description: "Similar to ZMQ, you can use Kafka to collect flows exported by nProbe. In order to do this you can specify kafka://[;;] or kafka-ssl://[;;] depending if..."
outline: [2, 3]
lastUpdated: 2025-02-12T16:12:50+01:00
---

<a id="kafkaflowcollection"></a>

# Collecting nProbe Flows Using Kafka {#collecting-nprobe-flows-using-kafka}

Similar to ZMQ, you can use Kafka to collect flows exported by nProbe. In order to do this you can specify kafka://\&lt;broker>[;\&lt;topic>;\&lt;options>] or kafka-ssl://\&lt;broker>[;\&lt;topic>;\&lt;options>] depending if you use plain text or SSL/TLS connections to the Kafka broker. As usual you can specify multiple brokers IP (and ports) by splitting them with a comma (,).

## Example {#example}

Below you can find some examples:

> - Collect flows sent by nProbe to Kafka broker active on 127.0.0.1 on the default port (9092). Use: `-i kafka://127.0.0.1`
> - Collect flows sent by nProbe to Kafka brokers 127.0.0.1:7689, 192.168.1.20:9092 and 192.168.1.2:909. Use: `-i kafka://127.0.0.1:7689,192.168.1.20:9092,192.168.1.2:9092`

::: info
Topic names cannot be changed in ntopng/nProbe.
Please make sure that the topics are created on the kafka broker before exporting data. See [Kafka docs](https://kafka.apache.org/quickstart) for more information abotu Kafka configuration.
:::
