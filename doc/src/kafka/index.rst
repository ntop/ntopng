Kafka
#####

`Apache Kafka <https://kafka.apache.org>`_ is a popular message broker platform that is supported by ntopng (Enterprise M+ license is required). It can be used both as ZMQ drop-in replacement, or to deliver data produced by ntopng to remote consumers. Contrary to ZMQ, a Kafka broker implements some message persistency that enables applications (e.g. nProbe and ntopng) to be decoupled.

.. note::

    We suppose that the kafka broker has been already setup and configured in order to be used by ntopng.

   
Below you can read mode about how to use Kafka with ntopng (and nProbe):

.. toctree::
    :maxdepth: 2

    export_flows
    collect_flows
    send_kafka_messages
