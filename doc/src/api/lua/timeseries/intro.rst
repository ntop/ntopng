Basic Concepts and Export
#########################

Here is a brief introduction to some fundamental concepts of the API.

Driver
------

A timeseries *driver* implements a well defined interface to provide support for a
specific database. Currently ntopng provides the RRD and InfluxDB drivers to communicate
with the respective datatabases.

Schema
------

A schema can be seen as a table of a database. It specifies the data format and types.
A schema is identified by it's name and contains the following informations:

  - Step: the expected interval, in seconds, between raw data points.

  - Tags: a tag is a label which can be used to filter data. Example of tags are
    the interface name, host name and nDPI protocol name.

  - Metrics: a metric is a particual value which is being measured. Example of metrics are
    the host bytes sent traffic, interface number of flows and ASN round trip time.
    All metrics must be consistent with the specified type (see below).

  - Type: the type for all the metrics of the schema. Currently "counter" or "gauge".

  - Options: some driver specific options.

All the ntopng defined schemas can be found in `scripts/lua/modules/timeseries/schemas`.
Schemas are split into 3 files, one for each periodic script, to avoid wasting time loading
unnecessary schemas. Nevertheless, by including the `ts_utils` module, all the available
schemas are loaded automatically.

Exporting Data
--------------

Thanks to the formalization of the data into schemas, ntopng itself can now
be used as a timeseries exporter. The script `scripts/lua/get_ts.lua` is the
endpoint which provides such data.

Let's see how to read a particuar host nDPI traffic by using the provided API.

The "host:ndpi" schema is defined in `ts_5min.lua` as follows:

.. code-block:: lua

  schema = ts_utils.newSchema("host:ndpi", {step=300})
  schema:addTag("ifid")
  schema:addTag("host")
  schema:addTag("protocol")
  schema:addMetric("bytes_sent")
  schema:addMetric("bytes_rcvd")

In order to extract last hour host `192.168.1.10` information about the
Facebook protocol, the following API can be used.

To extract data from a Lua script located within the ntopng directory structure:

.. code-block:: lua

  local res = ts_utils.query("host:ndpi", {
    ifid = "1",
    host = "192.168.1.10",
    protocol = "Facebook"
  }, os.time()-3600, os.time())

  --tprint(res)

To extract data from an external program:

.. code-block:: bash

  # Extract host traffic in the specified time frame
  curl --cookie "user=admin; password=admin" "http://127.0.0.1:3000/lua/get_ts.lua?ts_schema=host:traffic&ts_query=ifid:1,host:192.168.1.10&epoch_begin=1532180495&epoch_end=1532176895"

  # Extract last hour top host protocols
  curl --cookie "user=admin; password=admin" "http://127.0.0.1:3000/lua/get_ts.lua?ts_schema=top:host:ndpi&ts_query=ifid:1,host:192.168.43.18"

  # Extract last hour AS 62041 RTT
  curl --cookie "user=admin; password=admin" "http://127.0.0.1:3000/lua/get_ts.lua?ts_query=ifid:1,asn:62041&ts_schema=asn:rtt"

JSON data will be returned. Check out the `ts_utils` module documentation below to
learn more about the query response format.
