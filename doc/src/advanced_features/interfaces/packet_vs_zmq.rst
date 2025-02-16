.. _PacketVsZMQInterfaces:

Packet vs ZMQ Interfaces
########################

ntopng handles two types of interfaces, namely:

  - Packet interfaces
  - ZMQ interfaces

Packet Interfaces
=================

In general, packet interfaces are devices capable of sending and receiving network packets. Such devices, also known as Network Interface Controllers (NICs), can be:

  - Physical pieces of hardware attached to a computer
  - Virtual devices attached to virtual machines

ntopng has the ability to attach to such packet interfaces and read all the packets that are being sent or received.

ZMQ Interfaces
==============

Attaching to a packet interface requires ntopng to be running on the same host of the interface and this is not always practicable. For this reason, ntopng supports ZMQ interfaces. ZMQ interfaces are capable of receiving traffic data from remote nProbe instances (see for example :ref:`UseCaseMultipleLocationsMonitoring`) either through the public Internet or private networks.

Traffic data sent over ZMQ interfaces are actually flows that are pre-computed by nProbe before being sent to ntopng. Attaching to such ZMQ interfaces doesn't allow ntopng to see any traffic packet - it just receives pre-computed flows with aggregated data such as:

  - Bytes sent from the client to the server and from the server to the client
  - Client and server network latency

Traffic Analysis: Differences
=============================

Using packet or ZMQ interfaces has some implications in terms of traffic analysis.

Using packet interfaces allows ntopng to perform the finest-grained traffic analyses as every single bit of every packet going through the interface is seen.

Contrarily, using ZMQ interfaces introduces some limitations on the type of traffic analyses that can be done due to the fact that not all the packets are seen by ntopng. Moreover, the information sent is user-controlled with the nProbe template (see nProbe option :code:`-T`) so there may be pieces of information not delivered to ntopng.

.. note::

	Limitations, however, only affect special cases. In general, limitations don't kick in for common traffic analyses such as bytes and packets sent and received, as well as procotocols and applications.

Packet vs ZMQ: Which One to use?
================================

Use packet interfaces when:

  - ntopng can be run on the same host of the interface (e.g., :ref:`UseCaseMirrorSPANTAPMonitoring`)

Use ZMQ interfaces when:

  - ntopng is used to monitor multiple locations (e.g., :ref:`UseCaseMultipleLocationsMonitoring`)
  - For Netflow/sFlow monitoring (e.g., :ref:`UseCaseNetflowSflowMonitoring`)
