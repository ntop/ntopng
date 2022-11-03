.. _KafkaFlowexport

Exporting Flows to Kafka
------------------------

Similar to other export methods such as ClickHouse and Elastic, you can instruct ntopng to export flows to Kakfa using the :code:`-F` option. The format of this option is the following

.. code:: bash

    kafka;[<brokerIP[:<port>]]+;<topic>[;<kafka option>=<value>]+

Where

- :code:`<brokerIP[:<port>]` Specifies the address of the kafka broker(s) used by ntopng. You can specify the port or omit it to use the default one. If you have multiple brokers to use, you can use a comma (,) to split them.  
- :code:`<topic>` Specifies the Kafka topic name to which ntopng exported flows will be sent to.
- :code:`<options>` You can specify options to be used during kafka connection. You can specify multiple options by splitting them with a comma (,). You can read the whole list of `supported kakfa options <https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md>`_ to know what options are supported.


Example
-------

Below you can find some examples:

  - Export flows to the topic ntopng_flows to a Kafka broker running on the same host where ntopng runs and listening on the default port (9092). Use: ::code:`kafka;127.0.0.1;ntopng_flows`.
  - Export flows to brokers 127.0.0.1:7689, 192.168.1.20:9092 and 192.168.1.2:9091 and compress data (when talking to Kafka) using gzip. Use: ::code:`kafka;127.0.0.1:7689,192.168.1.20,192.168.1.2;ntopng_flows;compression.codec=gzip`.
