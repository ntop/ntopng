---
title: "Installation"
description: "In order to install ClickHouse refer to the official [guide] by useing the following packages:"
outline: [2, 3]
lastUpdated: 2025-11-26T17:24:13+01:00
---
# Installation {#installation}

In order to install ClickHouse refer to the official [guide] by useing the following packages:

- Debian/Ubuntu: <https://clickhouse.com/docs/en/install/#install-from-deb-packages>
- RedHat/RockyLinux: <https://clickhouse.com/docs/en/install/#from-rpm-packages>
- FreeBSD/Other: <https://clickhouse.com/docs/en/install#quick-install> (read the notes below)

::: warning
- Make sure that ClickHouse **version 22 or newer** is installed. Older versions are not supported as they lack important features such as the MySQL compatibiity layer.
- In case multiple ntopng instances write to the **same** ClickHouse database they must have different instance names. By default ntopng uses the hostname as instance name, but in case such names are **not unique**, please consider using the `--instance-name` command line option to set the custom instance name to an unique value for all the ntopng instances writing to the same database.
:::

::: info
The ClickHouse database (server) can run anywhere, both locally on the machine running ntopng, or on a remote machine. However, the clickhouse client (`clickhouse` or `clickhouse-client`) must always be installed locally as it is used by ntopng to connect to the ClickHouse server.
:::

## FreeBSD Notes {#freebsd-notes}

On FreeBSD please make sure that the clickhouse binary is placed under /usr/local/bin in order to be detected by ntopng.

It is possible to download the binary following the instructions available on the official [guide], and install it with `./clickhouse install` or manually as follows:

```bash
curl https://clickhouse.com/ | sh
mv clickhouse /usr/local/bin/
```

## Cluster Configuration {#cluster-configuration}

For large deployments or data replication, a cluster is a better option with respect to a stand-alone database deployment. At [this page](https://github.com/ntop/ntopng/tree/dev/clickhouse) we share simple configuration notes for deploying a ClickHouse cluster in minutes.

## ClickHouse Cloud {#clickhouse-cloud}

In case instead of ClickHouse Cloud, the configuration is quite simple; after creating the service on ClickHouse Cloud, enable the MySQL Connection from the `Connect` section.
Then add to the ntopng configuration file the `-F` option correctly configured:

```bash
clickhouse-cloud;<host[@port]|socket>;<dbname>;<clickhouse-user>,<mysql-user>;<pw>;<cluster name>
```

For example:

```bash
./ntopng -F "clickhouse-cloud;my-cloud-host.clickhouse.org@9440,3306s;ntopng;ch-user,mysql-user;ch-password"
```

::: info
The `s` after the ports, means to use a secured connection, see for more info.
:::

::: info
Even when using ClickHouse Cloud, clickhouse-client is needed in the local machine.
:::

## ClickHouse Tuning {#clickhouse-tuning}

The defaut ClickHouse service configuration is not optimized in terms of memory and disk utilization.
In order to reduce utilization of such resources please [refer to this guide](https://github.com/ntop/ntopng/blob/dev/doc/README.clickhouse.md)
that explain in detail how to optimize the database configuration.

[guide]: https://clickhouse.com/docs/en/getting-started/quick-start/
