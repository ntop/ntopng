.. _KafkaSendmessages

Sending Messages to Kafka
------------------------

In addition of flow export and collection, you can use kafka from Lua scripts to deliver messages to remote recipients. This can be achieved using the API call :code:`ntop.sendKafkaMessage(<broker>,<message>)`. This function takes as input two strings:

  - the broker string specifies how to connect to Kafka infrastructure. Its format is :code:`<broker IPs>;<topic>;<options>`. As already described, the broker IPs are separated with commas (,) and they can have an optional port. The :code:`topic` specifies where to deliver messages to, and the :code:`<options>` contains optional specifications used when connecting with the broker. You can read the whole list of `supported kafka options <https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md>`_ to know what options are supported.
  - the string message to be delivered to the specified topic.

Example
=======

Below you can find some examples:

  - Send the "Hello World" string to the topic hello: :code:`ntop.sendKafkaMessage("127.0.0.1;hello;", "Hello World")`
  - Send the "Say hello to ntopng !" string to the topic of broker 192.168.1.1:9092, info using a compressed connection: :code:`ntop.sendKafkaMessage("192.168.1.1;info;compression.codec=gzip", "Hello World")`
    
