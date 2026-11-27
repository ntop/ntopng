---
title: "Sending Messages to Kafka"
description: "In addition of flow export and collection, you can use kafka from Lua scripts to deliver messages to remote recipients. This can be achieved using the API..."
outline: [2, 3]
lastUpdated: 2025-02-12T16:12:50+01:00
---

<a id="kafkasendmessages"></a>

# Sending Messages to Kafka {#sending-messages-to-kafka}

In addition of flow export and collection, you can use kafka from Lua scripts to deliver messages to remote recipients. This can be achieved using the API call `ntop.sendKafkaMessage(<broker>,<message>)`. This function takes as input two strings:

> - the broker string specifies how to connect to Kafka infrastructure. Its format is `<broker IPs>;<topic>;<options>`. As already described, the broker IPs are separated with commas (,) and they can have an optional port. The `topic` specifies where to deliver messages to, and the `<options>` contains optional specifications used when connecting with the broker. You can read the whole list of [supported kafka options](https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md) to know what options are supported.
> - the string message to be delivered to the specified topic.

## Example {#example}

Below you can find some examples:

> - Send the "Hello World" string to the topic hello: `ntop.sendKafkaMessage("127.0.0.1;hello;", "Hello World")`
> - Send the "Say hello to ntopng !" string to the topic of broker 192.168.1.1:9092, info using a compressed connection: `ntop.sendKafkaMessage("192.168.1.1;info;compression.codec=gzip", "Hello World")`
