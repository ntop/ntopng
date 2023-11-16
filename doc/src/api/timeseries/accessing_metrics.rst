Accessing Metrics
#################

A full list of all the metrics already built-in and exported as timeseries into ntopng is available in the Metrics section.
This section provides a couple of examples for accessing those metrics.

Interface Metrics
=================

Supported metrics for the creation of interface timeseries are:

  - Layer-7 applications bytes sent and received
  - Layer-4 TCP, UDP, ICMP bytes sent and received
  - Total bytes sent and received
  - Total alerts
  - etc.

An always-updated list of metrics can be determined by inspecting
method :code:`NetworkInterface::lua`:
https://github.com/ntop/ntopng/blob/dev/src/NetworkInterface.cpp

Interface metrics are available as a Lua table. An excerpt of such
table is shown below:

.. code-block:: lua

   speed number 1000
   id number 1
   stats table
   stats.http_hosts number 0
   stats.drops number 0
   stats.devices number 2
   stats.current_macs number 6
   stats.hosts number 23
   stats.num_live_captures number 0
   stats.bytes number 50559082
   stats.flows number 30
   stats.local_hosts number 3
   stats.packets number 64984


Host Metrics
============

Supported metrics for the creation of host timeseries are:

  - Layer-7 applications bytes sent and received
  - Layer-4 TCP, UDP, ICMP bytes sent and received
  - Total bytes sent and received
  - Active flows as client and as server
  - Anomalous flows as client and as server
  - Total alerts
  - Number of hosts contacted as client
  - Number of hosts contacts as server

An always-updated list of host metrics can be determined by inspecting
this file:
https://github.com/ntop/ntopng/blob/dev/src/HostTimeseriesPoint.cpp

Host metrics are available in an handy Lua table such as the one
exemplified below:

.. code-block:: lua

   ndpi_categories table
   ndpi_categories.Cloud number 2880
   misbehaving_flows.as_server number 0
   active_flows.as_client number 0
   bytes.rcvd number 2880
   icmp.bytes.rcvd number 0
   tcp.bytes.rcvd number 0
   total_alerts number 0
   udp.bytes.rcvd number 2880
   icmp.bytes.sent number 0
   other_ip.bytes.rcvd number 0
   other_ip.bytes.sent number 0
   misbehaving_flows.as_client number 0
   contacts.as_server number 1
   bytes.sent number 0
   instant number 1550836500
   tcp.bytes.sent number 0
   udp.bytes.sent number 0
   contacts.as_client number 0
   ndpi table
   ndpi.Dropbox string 0|2880
   active_flows.as_server number 1

Specifically, Layer-7 application protocols are pushed in a table
:code:`ndpi`, whose keys are the application names such as
:code:`Dropbox`. For every application there are two values separated
by a pipe, namely, bytes sent and bytes received. For example, in the
excerpt above, :code:`Dropbox` application had received 0 bytes and
had sent 2880 bytes at the time the excerpt was generated.
   
The table also contain a field :code:`instant` that represents the
time at which metrics have been sampled.

The table above can be accessed and its contents can be read/modified
to prepare timeseries points.
