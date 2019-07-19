Timeseries
##########

Ntopng creates historical timeseries to be visualized in the charts. In order to
store timeseries data, ntopng supports RRD_ and InfluxDB_ as timeseries drivers.

.. figure:: ../img/basic_concepts_timeseries_preferences.png
  :align: center
  :alt: Timeseries Preferences
  :scale: 80

  Timeseries Preferences

The resolution of data depends on the actual timeseries type. For example, the
network interfaces traffic is usually recorded with a 1 second resolution, whereas the
hosts L7 protocols data usually have 5 minutes resolution. Moreover, in same cases (e.g. RRD),
the resolution of the data depends on how old is the data.

RRD Driver
----------

RRD is the default driver used. It writes data in the form of local `.rrd` files.
With RRD the retention time for recorded data is fixed 1 year. RRD automatically
aggregates old data to save space, reducing its resolution. Hence older data will be
aggregated together and finally be removed after 1 year (in fact RRD stands for *Round Robin*
Database).

Querying a single data series is efficient since the data is contained into a single file,
while performing more complex queries on multiple data series (e.g. when trying to determine
the top protocols) can take some time. Moreover RRD has shown some limitations when writing
a large volume of data, usually leading to gaps in the timeseries data points. With a large
volume of data, the use of InfluxDB is suggested.

InfluxDB Driver
---------------

ntopng supports writing and fetching timeseries data from an InfluxDB server.
Since database communication happens via the network, the server can also be located
on an external host.

.. note::

   The minimum supported InfluxDB version is 1.5.1

.. figure:: ../img/basic_concepts_influxdb_settings.png
  :align: center
  :alt: InfluxDB Preferences
  :scale: 80

  InfluxDB Preferences

Here is an overview of the features ntopng provides:

- A database is automatically configured according to the *InfluxDB Database* field value
- It is possible to specify the db authentication credentials if the InfluxDB database is protected
- It is possible to specify the maximum retention time for data

InfluxDB is really suitable to export high frequency data due to the high insertion
throughput. For this reason it's possible to increase the timeseries resolution to
get more detailed historical data. This can be configured from the
"L7 Application Resolution" preference.

.. warning::

  Increasing the timeseries resolution involves more buffering into ntopng. This
  will have a strong impact on the RAM usage on large networks.

.. warning::

  In order to avoid "max-values-per-tag limit exceeded" errors with InfluxDB leading to
  new data being rejected, it's necessary to set `max-values-per-tag = 0` in the
  InfluxDB configuration file, usually located at `/etc/influxdb/influxdb.conf`

.. note::

  It is possible to review the current InfluxDB storage size used by ntopng from the
  "Runtime Status" page.

InfluxDB status can be monitored from the System menu, entry "InfluxDB".

.. figure:: ../img/basic_concepts_influxdb_status.png
  :align: center
  :alt: InfluxDB Status

  InfluxDB Status

The InfluxDB status home page shows a series of measures useful to
understand the current health of InfluxDB and export status. The
"Health" badge can be "green", "yellow" or "red", depending on the
current export status:

 - A "green" badge means that the export is working properly;
 - A "yellow" badge means there are issues with the export (for
   example ntopng is not able to reach InfluxDB) but such errors are
   recoverable and no data is lost;
 - A "red" badge means there are issues with the export that are
   non-recoverable and this led to the loss of data points.

It is important to note that the "Health" represent a current
picture, for past issues one should browse the "Alerts" page.

The other metrics shown in the status page have the following meaning:

 - "Storage Utilization" indicates the disk space taken by the
   InfluxDB database which is being populated by ntopng. The number
   takes into account all the shards, in case of a distributed setup.
 - "RAM" is an estimation of the amount of memory which is taken by
   the InfluxDB process.
 - "Total Exports" is a counter of the number of times ntopng has
   successfully performed :code:`POST` operations to the InfluxDB
   :code:`/write` endpoint to write points.
 - "Total Points" is a counter of the total number of points ntopng
   has successfully written to InfluxDB, across all the "Total Exports".
 - "Dropped Points" counts the number of points ntopng has dropped as
   it could not successfully export them to InfluxDB. Points are only
   dropped after several attempts, that is, ntopng will try and
   contact InfluxDB several times before actually dropping
   points. Reasons for dropped points could be an unreachable, down, overloaded or
   significantly impaired InfluxDB.
 - "Series Cardinality" provides an indication of how challenging it is
   for InfluxDB to handle written points. High  series cardinality is
   a primary driver of high memory usage for many database workloads.
   Hardware sizing guidelines for series cardinality
   recommendations are available based on the hardware.

"Total Exports", "Total Points" and "Dropped Points" are cumulative
counters since the startup of ntopng.
   
Timeseries Configuration
------------------------

Individual timeseries can be enabled or disabled based on the user needs or system
limits. Such limits usually are:

- the storage size (more timeseries means more storage)
- the storage speed
- the time needed to write such timeseries to the timeseries db (in particular, this is
  a problem with RRD)

Moreover, having a lot of timeseries usually means slower query time.

.. figure:: ../img/basic_concepts_timeseries_to_enable.png
  :align: center
  :alt: InfluxDB Preferences
  :scale: 80

Enabling a "Traffic" timeseries usually has little impact on the performance. On the
other hand, enabling the "Layer-7 Applications" (in particular for the local hosts)
has a high impact since there are many protocols and timeseries must be processed
for each of them.

It is possible to skip timeseries generation for a particular network interface
from the interface settings page. By disabling timeseries generation on a network
interface, no timeseries data will be written for the interface itself and for
all the local hosts belonging to it.

.. figure:: ../img/basic_concepts_timeseries_to_enable_interface.png
  :align: center
  :alt: Per Interface Settings
  :scale: 80

ntopng also provides timeseries on other traffic elements such as Autonomous Systems,
Countries, VLANs and so on, which can be enabled independently.

.. figure:: ../img/basic_concepts_timeseries_to_enable_2.png
  :align: center
  :alt: InfluxDB Preferences
  :scale: 80


.. _RRD: https://oss.oetiker.ch/rrdtool

.. _InfluxDB: https://www.influxdata.com
