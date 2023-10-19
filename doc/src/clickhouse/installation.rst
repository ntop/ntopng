Installation
------------

In order to install ClickHouse refer to the official guide_ by useing the following packages:

- Debian/Ubuntu: https://clickhouse.com/docs/en/install/#install-from-deb-packages
- RedHat/RockyLinux: https://clickhouse.com/docs/en/install/#from-rpm-packages



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

