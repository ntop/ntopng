Querying Data
#############

When using InfluxDB as timeseries backend in ntopng, it is possible to explore 
data by running queries with the InfluxQL SQL-like query language. In order to 
run queries it is possible to use the *influx* CLI tool itself, which ispart of 
the *influxdb-client* package.

The following sections provide examples of queries using the InfluxQL SELECT 
statement that cover common use cases.

Number Of Hosts In The Last Minute
==================================

- **Type**: gauge 
- **Query**:

.. code:: sql

   SELECT "num_hosts" FROM "iface:hosts" 
   WHERE ifid='1' and time >= now()-60s and time <= now()


Traffic On An Interface In The Last Minute
==========================================

- **Type**: counter
- **Query**:

.. code:: sql

   SELECT NON_NEGATIVE_DERIVATIVE("bytes") FROM "iface:traffic" 
   WHERE ifid='1' AND time >= now() - 60s AND time <= now()

Traffic On An Interface In The Last Hour, Per Minute
====================================================

- **Type**: counter
- **Query**:

.. code:: sql

   SELECT NON_NEGATIVE_DERIVATIVE(mean("bytes"))/60 FROM "iface:traffic" 
   WHERE ifid='1' AND time >= now() - 1h AND time <= now() group by time(60s)

Traffic On An Interface In The Last Hour
========================================

- **Type**: counter
- **Query**:

.. code:: sql

   SELECT SUM(value) FROM (
      SELECT NON_NEGATIVE_DIFFERENCE("bytes") as value FROM "iface:traffic" 
      WHERE ifid='1' AND time >= now() - 1h AND time <= now())

