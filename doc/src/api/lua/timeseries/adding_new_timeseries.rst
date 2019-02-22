Adding New Timeseries
#####################

To add a new timeseries it is necessary to define its schema.
Schemas are defined in lua files under
:code:`scripts/lua/modules/timeseries/schemas/`. As in general
timeseries points are added at regular intervals of time, lua files
are named as :code:`ts_5min.lua`, :code:`ts_min.lua` etc to keep
schemas ordered. The programmer will add a schema for a timeseries which
receives a new point every 5 minutes in file
:code:`ts_5min.lua`. Similarly, a timeseries which receives a point
every minute will have its schema defined in file :code:`ts_min.lua`.

Once the schema is defined, it is necessary to :code:`append` points to
the timeseries. The function used to append points to the timeseries
is the :code:`ts_utils.append` documented later in this section of the
documentation.

Example
=======

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
