ClickHouse
##########

ntopng (Enterprise M/L license is required) integrates with ClickHouse to store historical flows and alerts. ClickHouse is an high-performance SQL database. To install ClickHouse refer to the official guide_.

.. _guide: https://clickhouse.com/#quick-start

.. note::

   Please make sure that ClickHouse **version 22 or newer** is installed. Older versions are not supported as they lack important features such as the MySQL compatibiity layer.

.. note::

   The ClickHouse database can be executed anywhere, both locally on the machine running ntopng or on a remote machine. However, :code:`clickhouse-client` must always be installed locally as it is used by ntopng to connect to ClickHouse. This installation guide_ explains how to install it.

.. toctree::
    :maxdepth: 2

    clickhouse
    historical_flow_explorer
