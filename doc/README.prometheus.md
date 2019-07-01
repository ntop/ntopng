Introduction
------------
This readme explains how to integrate ntopng with http://prometheus.io time series database.
Prometheus polls data from ntopng that must expose the /metrics URL (pull model).


Installation
------------
After installing prometheus, in order to run it you will need a configuration file.
You can use the one provided in the [https://prometheus.io/docs/introduction/getting_started/] (getting started guide).

```
prometheus --config.file=/etc/prometheus/prometheus.yml
```

You may also want to enable the admin API (for example to delete old
timeseries). In this case, add the corresponding option

```
prometheus --config.file=/etc/prometheus/prometheus.yml --web.enable-admin-api
```

By default, it will start a webserver on port 9090. Verify the connection before proceeding.

In order to start monitoring ntopng,

[1] Go inside ntopng preferences -> Timeseries then select Prometheous and save it

[2] you should add a new job to the `scrape_configs` section in your prometheus.yml:

```
# A scrape configuration containing exactly one endpoint to scrape:
scrape_configs:
  - job_name: 'ntopng'

    # This is the polling interval. It will affect your data resolution and cpu load.
    # NOTE: keep in sync with "poll_interval" in metrics.lua
    scrape_interval: 10s

    target_groups:
      # This must match your ntopng host and port
      - targets: ['localhost:3000']
```

Since prometheus does not support custom HTTP headers for authentication, you have two options:
  - disable ntopng login, either locally (-l 0) or both locally and remotely (-l 1)
  - setup an HTTP proxy like nginx to add authentication headers through it


Visualization
-------------
You can connect to the prometheus GUI at http://localhost:9090 and see timeseries


LIMITATION
----------

Currently ntopng is able to write into prometheus but not to read from it and display data in the GUI
