.. _KafkaFlowcollection

Collecting nProbe Flows Using Kafka
-----------------------------------

Similar to ZMQ, you can use Kafka to collect flows exported by nProbe. In order to do this you can specify kafka://<broker> or kafka-ssl://<broker> depending if you use plain text or SSL/TLS connections to the Kafka broker. As usual you can specify multiple brokers IP (and ports) by splitting them with a comma (,).

Example
=======

Below you can find some examples:

  - Collect flows sent by nProbe to Kafka broker active on 127.0.0.1 on the default port (9092). Use: :code:`-i kafka://127.0.0.1`
  - Collect flows sent by nProbe to Kafka brokers 127.0.0.1:7689, 192.168.1.20:9092 and 192.168.1.2:909. Use: :code:`-i kafka://127.0.0.1:7689,192.168.1.20:9092,192.168.1.2:9092`
