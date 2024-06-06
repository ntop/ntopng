Installation
------------

In order to install ClickHouse refer to the official guide_ by useing the following packages:

- Debian/Ubuntu: https://clickhouse.com/docs/en/install/#install-from-deb-packages
- RedHat/RockyLinux: https://clickhouse.com/docs/en/install/#from-rpm-packages
- FreeBSD/Other: https://clickhouse.com/docs/en/install#quick-install


.. _guide: https://clickhouse.com/docs/en/getting-started/quick-start/

.. warning::

   - Make sure that ClickHouse **version 22 or newer** is installed. Older versions are not supported as they lack important features such as the MySQL compatibiity layer.
   - In case multiple ntopng instances write to the **same** ClickHouse database they must have different instance names. By default ntopng uses the hostname as instance name, but in case such names are **not unique**, please consider using the :code:`--instance-name` command line option to set the custom instance name to an unique value for all the ntopng instances writing to the same database.
     
     .. note::

   The ClickHouse database can be executed anywhere, both locally on the machine running ntopng or on a remote machine. However, :code:`clickhouse-client` must always be installed locally as it is used by ntopng to connect to ClickHouse. This installation guide_ explains how to install it.
   For non-Linux platforms as **FreeBSD** the client is installed as follows: :code:`./clickhouse install`
   
Cluster Configuration
=====================

For large deployments or data replication, a cluster is a better option with respect to a stand-alone database deployment. At `this page <https://github.com/ntop/ntopng/tree/dev/clickhouse>`_ we share simple configuration notes for deploying a ClickHouse cluster in minutes.

ClickHouse Cloud
================

In case instead of ClickHouse Cloud, the configuration is quite simple; after creating the service on ClickHouse Cloud, enable the MySQL Connection from the `Connect` section.
Then add to the ntopng configuration file the `-F` option correctly configured:

.. code:: bash
	  
    clickhouse-cloud;<host[@port]|socket>;<dbname>;<clickhouse-user>,<mysql-user>;<pw>;<cluster name>

For example:

.. code:: bash

    ./ntopng -F="clickhouse-cloud;my-cloud-host.clickhouse.org@9440,3306s;ntopng;ch-user,mysql-user;ch-password"

.. note::
  The `s` after the ports, means to use a secured connection, see for more info.

.. note::
  Even when using ClickHouse Cloud, clickhouse-client is needed in the local machine.
