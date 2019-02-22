Custom Timeseries
#################

Adding Custom Timeseries
========================

ntopng supports the creation of custom timeseries for:

  - Local hosts
  - Interfaces

Neither remote hosts nor flows can be used when creating custom
timeseries.

Custom timeseries can be created out of the following host metrics:

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
exemplified below

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

ntopng handles custom timeseries with updates every:

  - 1 minute
  - 5 minutes

This means that custom timeseries with a point every minute and a
point every minutes can be generated, respectively.

In the remaining part of this section it is shown how to
programmatically add custom timeseries.

Schema
------

To add a custom timeseries it is necessary to define its schema.
Schemas are defined in lua files under
:code:`scripts/lua/modules/timeseries/schemas/`.

ntopng looks for custom timeseries schemas in the following lua files under
:code:`scripts/lua/modules/timeseries/schemas/`:

  - :code:`ts_5min_custom.lua` for timeseries with 1-minute updates
  - :code:`ts_minute_custom.lua` for timeseries with 5-minute updates

If file :code:`ts_5min_custom.lua` does not exist, ntopng will skip the
creation of custom timeseries with 5-minute updates. Similarly, if
file :code:`ts_minute_custom.lua` does not exist, ntopng will skip the
creation of custom timeseries with 1-minute updates.

Appending Timeseries Points
---------------------------

Once the schema is defined, it is necessary to :code:`append` points to
the timeseries. The function used to append points to the timeseries
is the :code:`ts_utils.append` documented later in this section of the
documentation.

Sample files :code:`ts_5min_custom.lua.sample` and :code:`ts_minute_custom.lua.sample` are
created automatically upon ntopng installation with some example
contents. Those files are ignored by ntopng. However, it is safe to
copy them to :code:`ts_5min_custom.lua` and
:code:`ts_minute_custom.lua` and modify the copies when it is necessary to
add custom timeseries.

Example
-------

Let's see how to add a timeseries that counts the number of anomalous
flows of a given host. An host can have anomalous flows both as client
and as server, therfore, the resulting timeseries will receive two
points every :code:`append`, namely :code:`flows_as_client` and
:code:`flows_as_server`. These points are the *metrics* of the
timeseries that is being added.

Since an host always belongs to an interface, and the same host can be
seen on multiple interfaces, the schema will also need two fields,
namely, :code:`ifid` and :code:`host` to make sure a timeseries is
always uniquely identified. These fields are known as the *tags* of
the metric.

The resulting schema is:

.. code-block:: lua

		schema = ts_utils.newSchema("host:anomalous_flows", {step = 300})
		schema:addTag("ifid")
		schema:addTag("host")
		schema:addMetric("flows_as_client")
		schema:addMetric("flows_as_server")


As this timeseries is updated every 5 minutes, the schema above is
added in file
:code:`scripts/lua/modules/timeseries/schemas/ts_5min.lua`.

Now, to actually add points to the timeseries, it suffices to call the
:code:`ts_utils.append`. This function can be called in file
:code:`ts_5min_dump_utils.lua` as that particular file is executed
every 5 minutes. Specifically, function
:code:`ts_dump.host_update_stats_rrds`, called for every local host,
can be extended to update this new timeseries.

The resulting call is:

.. code-block:: lua

		ts_utils.append("host:anomalous_flows", {ifid = ifstats.id, host = hostname,
		flows_as_client = host["anomalous_flows.as_client"],
		flows_as_server = host["anomalous_flows.as_server"]},
		when, verbose)

As it can be noted, the name of the timeseries,
:code:`host:anomalous_flows` is the same both in the schema and in the
append. Also the names of tags and metrics are the same. The table
:code:`host` used contains the host details (see
:code:`interface.getHostInfo`) and the anomalous flows are extracted
from there.

From that point on, the timeseries will be consistently updated by ntopng.

Locating Stored Custom Timeseries
=================================

TODO

Charting Custom Timeseries
==========================

TODO

