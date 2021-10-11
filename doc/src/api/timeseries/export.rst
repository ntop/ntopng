Exporting Data
##############

Thanks to the formalization of the data into schemas, ntopng itself can now
be used as a timeseries exporter. The script `scripts/lua/rest/get/timeseries/ts.lua` is the
endpoint which provides such data.

Let's see how to read a particuar host nDPI traffic by using the provided API.

The "host:ndpi" schema is defined in `ts_5min.lua` as follows:

.. code-block:: c

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

  # Extract last hour interface traffic (change ifid:1 accordingly)
  curl -s --cookie "user=admin; password=admin" "http://127.0.0.1:3000/lua/rest/get/timeseries/ts.lua?ts_schema=iface:traffic&ts_query=ifid:1&extended=1"

  # Extract host traffic in the specified time frame
  curl -s --cookie "user=admin; password=admin" "http://127.0.0.1:3000/lua/rest/get/timeseries/ts.lua?ts_schema=host:traffic&ts_query=ifid:1,host:192.168.1.10&epoch_begin=1532180495&epoch_end=1532176895&extended=1"

  # Extract last hour top host protocols
  curl -s --cookie "user=admin; password=admin" "http://127.0.0.1:3000/lua/rest/get/timeseries/ts.lua?ts_schema=top:host:ndpi&ts_query=ifid:1,host:192.168.43.18&extended=1"

  # Extract last hour AS 62041 RTT
  curl -s --cookie "user=admin; password=admin" "http://127.0.0.1:3000/lua/rest/get/timeseries/ts.lua?ts_query=ifid:1,asn:62041&ts_schema=asn:rtt&extended=1"

JSON data will be returned. Check out the `ts_utils` module documentation below to
learn more about the query response format.
