.. _UsingNtopngWithNprobeCollectorMode:

Using ntopng with nProbe (Collector Mode)
#########################################

ntopng in collector mode listens for incoming data over ZMQ. One or multiple nProbe can connect the ntopng to send their data.

To start ntopng in collector mode specify an extra :code:`c` at the end of the ZMQ endpoint.

For example, to start ntopng in collector mode and listen for incoming nProbe connections on port :code:`5556` the following configuration can be used

.. code:: bash

     ntopng -i tcp://*:5556c

The asterisk :code:`*` tells ntopng to listen on any address available. A specific address can be indicated in place of the asterisk, e.g.,

.. code:: bash

     ntopng -i tcp://127.0.0.1:5556c

In the configuration above, ntopng will only listens for nProbe connections arriving on :code:`localhost`.

To connect nProbe instances to ntopng listening in collector mode, the IP address of ntopng and extra :code:`--zmq-probe-mode` must be indicated in the nProbe configuration.

For example, to connect nProbe to a ntopng instance running in collector mode on host :code:`192.168.2.222` port :code:`5556` one can use

.. code:: bash

     nprobe --zmq tcp://192.168.2.222:5556 --zmq-probe-mode <other nprobe options>

Multiple nProbe instances can be connected to the same ntopng instance running in collector mode, using the very same configuration. ntopng is able to recognize individual nProbe instances automatically.

.. note::

   The number of nProbe instances that can be connected to a single ntopng instances is limited and depends on the license. Check the nProbe product page for the actual limits.

Use Cases
=========

It is necessary to start ntopng in collector mode when

- Multiple nProbe instances need to be connected to the same ntopng
- nProbe is behind a firewall and thus it must be the connection initiator

See :ref:`UsingNtopngWithNprobe` for additional details.




