Custom Timeseries
#################

ntopng supports the creation of custom timeseries for:

  - Local hosts
  - Interfaces

Neither remote hosts nor flows can be used when creating custom
timeseries.

Custom timeseries can be created out of metrics.

Interface Metrics
=================

Supported metrics for the creation of interface timeseries are:

  - Layer-7 applications bytes sent and received
  - Layer-4 TCP, UDP, ICMP bytes sent and received
  - Total bytes sent and received
  - Total alerts
  - etc.

An always-update list of metrics can be determined by inspecting
method :code:`NetworkInterface::lua`:
https://github.com/ntop/ntopng/blob/dev/src/NetworkInterface.cpp

Interface metrics are available as a lua table. An excerpt of such
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

Host metrics are available in an handy lua table such as the one
exemplified below:

.. code-block:: lua

   ndpi_categories table
   ndpi_categories.Cloud number 2880
   anomalous_flows.as_server number 0
   active_flows.as_client number 0
   bytes.rcvd number 2880
   icmp.bytes.rcvd number 0
   tcp.bytes.rcvd number 0
   total_alerts number 0
   udp.bytes.rcvd number 2880
   icmp.bytes.sent number 0
   other_ip.bytes.rcvd number 0
   other_ip.bytes.sent number 0
   anomalous_flows.as_client number 0
   contacts.as_server number 1
   bytes.sent number 0
   instant number 1550836500
   tcp.bytes.sent number 0
   udp.bytes.sent number 0
   contacts.as_client number 0
   ndpi table
   ndpi.Dropbox string 0|2880
   active_flows.as_server number 1

The table also contain a field :code:`instant` that represents the
time at which metrics have been sampled.

The table above can be accessed and its contents can be read/modified
to prepare timeseries points.

Adding Custom Timeseries
========================

ntopng handles custom timeseries with updates every:

  - 1 minute for interfaces
  - 5 minutes for local hosts

This means that custom timeseries with a point every minute and a
point every 5 minutes can be generated for interfaces and local hosts, respectively.

ntopng looks for custom timeseries in the following lua files under
:code:`scripts/lua/modules/timeseries/custom/`:

  - :code:`ts_minute_custom.lua` for local hosts timeseries with 5-minute updates
  - :code:`ts_5min_custom.lua` for interface timeseries with 1-minute updates

If file :code:`ts_5min_custom.lua` does not exist, ntopng will skip the
creation of custom timeseries with 5-minute updates. Similarly, if
file :code:`ts_minute_custom.lua` does not exist, ntopng will skip the
creation of custom timeseries with 1-minute updates.

Sample files :code:`ts_5min_custom.lua.sample` and :code:`ts_minute_custom.lua.sample` are
created automatically upon ntopng installation with some example
contents. Those files are ignored by ntopng. However, it is safe to
copy them to :code:`ts_5min_custom.lua` and
:code:`ts_minute_custom.lua` and modify the copies when it is necessary to
add custom timeseries.

Structure Custom Timeseries Files
---------------------------------

Every custom file must contain a method :code:`setup` which defines one or
more schemas. Every custom timeseries *needs* a schema to function. A
schema defines the timeseries in terms of tags and metrics. The
documentation describes what is a schema in detail. Later in this
section an example schema will be shown.

File :code:`ts_5min_custom.lua` must contain a callback
:code:`ts_custom.host_update_stats` which is called by ntopng every 5
minutes for every *active* local host. This callback accepts the
following arguments:

  - :code:`when` The time (expressed as a Unix Epoch) of the call
  - :code:`hostname` The IP address of the host, possibly followed by
    a VLAN tag
  - :code:`host` The host metrics in a lua table
  - :code:`ifstats` The interface stats of the host interface
  - :code:`verbose` and extra flag passed when ntopng is working in
    verbose mode

File :code:`ts_minute_custom.lua` must contain a callback
:code:`ts_custom.iface_update_stats` which is called by ntopng every
minute for every monitored interface. This callback accepts the
following arguments:

  - :code:`when` The time (expressed as a Unix Epoch) of the call
  - :code:`_ifname` The name of the monitored interface
  - :code:`ifstats` The interface stats of the monitored interface
  - :code:`verbose` and extra flag passed when ntopng is working in
    verbose mode

Callbacks can be used to append points to the timeseries. Indeed,
once the schema is defined, it is necessary to :code:`append` points to
the timeseries. The function used to append points to the timeseries
is the :code:`ts_utils.append` documented later in this section of the
documentation.

Example
-------

Let's see how to add an interface timseries that counts the number of
issues detected when analyzing sequence numbers. The total issues
detected when analyzing sequence numbers is considered as the sum of
TCP retransmitted, out-of-order and lost packets.

The first thing to do is to add a schema to the :code:`setup` function
of :code:`ts_minute_custom.lua`. The schema is created as as follows:

.. code-block:: lua

   schema = ts_utils.newSchema("iface:tcp_seq_errors", {step = 60})
   schema:addTag("ifid")
   schema:addMetric("packets")

The first argument of :code:`newSchema` specifies the timeseries name
:code:`"iface:tcp_seq_errors"`. Timeseries interfaces *must* start
with prefix :code:`iface:`. The second argument is a table that *must*
contain argument :code:`step` which tells how frequently the
timeseries will be updated. As we are in the 1-minute local hosts
timeseries lua script, a value of :code:`60` must be specified here.

Then, function :code:`addTag` is used to indicate an interface id
:code:`ifid` that will be used to uniquely identify the timeseries
when multiple interfaces are monitored. Finally, :code:`addMetric` is
called with an argument :code:`packets` to indicate the metric
name. Note that both the :code:`ifid` and :code:`packets` are just
plain strings here, their actual values will be set in the
:code:`ts_custom.iface_update_stats` when updating the timeseries with
new points.

To update the timeseries with new points, callback
:code:`ts_custom.iface_update_stats` is extended with a
:code:`ts_utils.append` call as follows.

.. code-block:: lua

   ts_utils.append("iface:tcp_seq_errors",
   {ifid = ifstats.id,
   packets = ifstats.tcpPacketStats.retransmissions
		+ ifstats.tcpPacketStats.out_of_order
		+ ifstats.tcpPacketStats.lost},
   when, verbose)

The first argument of :code:`ts_utils.append` is the timeseries name
and *must* be equal to the one specified when defining the schema. The
second argument is a table which *must* contain the tag (:code:`ifid`)
and the metric (:code:`packets`) which must be set to their actual
values. As it can be seen from the example above, the field :code:`id`
of table :code:`ifstats` is used to set tag :code:`ifid`, whereas the
sum of :code:`ifstats.tcpPacketStats` table fields
:code:`retransmissions`, :code:`out_of_order` and :code:`lost` are used
as value for the metric :code:`packets`.

Finally, the third argument :code:`when` is the time of the call, and
the latest argument :code:`verbose` indicates whether ntopng is
operating in verbose mode.

From that point on, the timeseries will be consistently updated by
ntopng.

Multiple schemas and multiple :code:`ts_utils.append` can be added in
the same file.

The full example can be seen at:
https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/timeseries/custom/ts_minute_custom.lua.sample

Another example that creates 5-minute timeseries of local hosts total
bytes can be seen at
https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/timeseries/custom/ts_5min_custom.lua.sample


Locating Stored Custom Timeseries
=================================

TODO

Charting Custom Timeseries
==========================

TODO

