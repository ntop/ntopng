Introduction
------------
This readme explains how to integrate ntopng with http://influxdb.org time series database.
Influx is populated by ntopng periodically pushing data into it, using the TimeSeriesExporter class.

**NOTE: ntopng requires influxdb 1.x (1.5.x and up), 2.x is not yet supported. **

Please install the latest influxdb 1.x from the official packages `https://portal.influxdata.com/downloads`.

Installation
------------
By default Influx data export is disabled. You can enabled as follows:

1. from the ntopng Timeseries preferences, select "InfluxDB" as the Timeseries Database
2. set the `InfluxDB URL` to point to the database: http://<host where Influx is running>:8086"
3. click save

and then ntopng will push data to Influx.

At this point ntop will use InfluxDB (and not RRD) to store timeseries. As you have exported data onto InfluxDB
you can also use Chronograf or Grafana to access your traffic metrics produced by ntopng.

Authentication
--------------

ntopng supports influxdb authentication.
A new privileged user can be created via the influxdb command line:

`CREATE USER admin WITH PASSWORD 'mysecret' WITH ALL PRIVILEGES`

Index format
-----------
In case you want to move from inmem to tsi1, you need to modify the file
/etc/influxdb/influxdb.conf and change the line as follows
index-version = "tsi1"

then restart influxdb and do 
sudo influx_inspect buildtsi -database ntopng -datadir /var/lib/influxdb/data/ -waldir /tmp/
sudo chown -R influxdb:influxdb /var/lib/influxdb/data/
