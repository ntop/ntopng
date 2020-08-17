Adding New Metrics
##################

Plugins allow users to create their own scripts and `custom pages`_ as long as
long as defining their own `timeseries schemas`_. This is often enough to add
custom metrics and visualize them. Some user however need to export
internal metrics from the ntopng core. The information that follow should give
a good starting point to do this.

.. _`custom pages`: ../../plugins/custom_pages.html
.. _`timeseries schemas`: ../../plugins/timeseries_schemas.html

General Overview
================

Traffic elements (such as local hosts and interfaces) are iterated periodically
and by some Lua scripts and their statistics are dumped in the form of timeseries.
Traffic elements are handled in some standard ways:

   1. Most traffic elements are implemented in C, and their statistics are passed
      to Lua via the :code:`::lua` method. For example, :code:`AutonomousSystem::lua` dumps
      the autonomous system statistics to Lua. *Important* if the element has a `::tsLua`
      method check out the case 2 below.

   2. Some other traffic elements are implemented in C, but their statistics are hold
      on a :code:`TimeseriesPoint` rather then the element itself. For example, the
      local hosts data is stored into the :code:`HostTimeseriesPoint` class. In order
      to add new timeseries for a local host, the :code:`HostTimeseriesPoint` is the
      class to modify (and related :code:`::lua` method).

   3. Some traffic elements are implemented in Lua. Their state is stored in Redis
      usually in json form. This includes, for example, the SNMP devices.

In order to add a custom timeseries it's necessary to identify the correct case
above. It's also important to note that not all the traffic elements can be exported.
Remote Hosts and Flows timeseries, for example, cannot be exported anyway due to the
design of ntopng.

Case 1: Adding metrics via the `::lua` method
---------------------------------------------

The new metric should be exposed into the :code:`::lua` method. Then, you can
simply add the metric to the `custom timeseries scripts`_. For example,
the autonomous systems `num_hosts` field, exposed into the :code:`AutonomousSystem::lua`
method, can be written as a timeseries in this way.

Please note that if the metric is already exposed into the :code:`::lua` method,
you can keep compatibility with the standard ntopng and update it normally (no ntopng fork needed).

Case 2: Adding metrics inside a `TimeseriesPoint`
-------------------------------------------------

In order to add a new metric to a LocalHost or NetworkInterface, the corresponding
:code:`TimeseriesPoint` should be modified instead:

   - For LocalHost, modify the :code:`HostTimeseriesPoint`
   - For NetworkInterface, modify the :code:`NetworkInterfaceTsPoint`

Things to keep in mind:

   - The new metric should be added to the header file (e.g. `HostTimeseriesPoint.h`).
   - The metric should be written to the :code:`TimeseriesPoint`, (e.g. in :code:`LocalHostStats::makeTsPoint`)
   - The metric should be exposed to Lua in the :code:`TimeseriesPoint:lua` method (e.g. in :code:`HostTimeseriesPoint::lua`)

After this, the metric should now be available in Lua. Use the `custom timeseries scripts`_
to export it as a timeseries. Since this requires modifications of the C source code,
compatibility with the standard ntopng cannot be preserved.

Case 3: Adding metrics for Lua only objects
-------------------------------------------

This really depends on the specific element to be added. Compatibility may or may not be assured.

.. _`custom timeseries scripts`: #custom-timeseries-scripts

Custom Timeseries Scripts
=========================

Once the new metrics are available in Lua via one of the methods discussed above,
it's necessary to export such metrics as timeseries. In order to do so, two actions are
required:

   - The metric format should be declared in a timeseries schema
   - The metric should be written to the timeseries driver

Both actions can be implemented inside the custom timeseries scripts.

ntopng handles custom timeseries with updates every:

  - 1 minute for interfaces
  - 5 minutes for local hosts

This means that custom timeseries with a point every minute and a
point every 5 minutes can be generated for interfaces and local hosts, respectively.

ntopng looks for custom timeseries in the following Lua files under
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

Structure of Custom Timeseries Scripts
--------------------------------------

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
  - :code:`host` The host metrics in a Lua table
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

Let's see how to add an interface timeseries that counts the number of
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
timeseries Lua script, a value of :code:`60` must be specified here.

Then, function :code:`addTag` is used to indicate an interface id
:code:`ifid` that will be used to uniquely identify the timeseries
when multiple interfaces are monitored. Finally, :code:`addMetric` is
called with an argument :code:`packets` to indicate the metric
name. Note that both the :code:`ifid` and :code:`packets` are just
plain strings here, their actual values will be set in the
:code:`ts_custom.iface_update_stats` when updating the timeseries with
new points.

The number of issues detected when analyzing sequence numbers is a
*counter*, that is, is an always-increasing function of
time. By default, schemas consider metrics as counters so there is no
need to specify this type upon schema addition. For *gauges*, one has
to indicate an extra :code:`metrics_type` in the table containing the
:code:`step`. So for example, to create a 1-minute timeseries for the number of
active flows of a given host, one can use the following syntax :code:`ts_utils.newSchema("host:flows", {step=60, metrics_type=ts_utils.metrics.gauge})`.

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

Charting New Metrics
====================

After exporting the new metrics to the timeseries driver (e.g. InfluxDB), the generated
timeseries can be charted inside the traffic element page. The particular script to
modify depends on the specific traffic element, here are some examples:

 - For local hosts, modify `host_details.lua`
 - For network interfaces, modify `if_stats.lua`

The script should contain a call to :code:`graph_utils.drawGraphs` with a :code:`timeseries` field.
The new timeseries should be added to it. Here is for example a modified host_stats.lua
with a new `host:low_goodput_flows` metric:

.. code:: lua

   graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
      top_protocols = "top:host:ndpi",
   ...
      timeseries = {
         {schema="host:traffic",                label=i18n("traffic")},
         {schema="host:flows",                  label=i18n("graphs.active_flows")},
         {schema="host:misbehaving_flows",        label=i18n("graphs.total_misbehaving_flows")},

         -- The new metric is added here in order to be shown into the charts
         {schema="host:low_goodput_flows",      label="Low Goodput Flows"},
   ...
      }
   })

The metric will appear with the "Low Goodput Flows" into the timeseries dropdown
after the timeseries points are available.
