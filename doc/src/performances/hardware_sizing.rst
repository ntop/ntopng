Hardware Sizing
===============

Indications on process, memory and disk required are given below for networks with three different sizes.

Network Size
------------

+--------------+---------------+---------------------------+-----------------------+
|              | Small Network | Medium Network            | Large Network         |
+--------------+---------------+---------------------------+-----------------------+
| Traffic      | < 100Mbps     | Between 100Mbps and 1Gbps | Above 1Gbps           |
+--------------+---------------+---------------------------+-----------------------+
| Active Hosts | Hundredths    | Thousands                 | Hundreds of thousands |
+--------------+---------------+---------------------------+-----------------------+
| Active Flows | Thousands     | Hundreds of thousands     | Millions              |
+--------------+---------------+---------------------------+-----------------------+

.. note::

  On large networks, special extra configuration is required as explained in :ref:`OperatingNtopngOnLargeNetworks`.

Processor and Memory
--------------------

+-----------+---------------+----------------+---------------+
|           | Small Network | Medium Network | Large Network |
+-----------+---------------+----------------+---------------+
| Processor | 2cores+       | 4cores+        | 8cores+       |
+-----------+---------------+----------------+---------------+
| Memory    | 2GB+          | 4GB+           | 16GB+         |
+-----------+---------------+----------------+---------------+

Disk
----

See `ntopng Disk Requirements for Timeseries and Flows <https://www.ntop.org/ntopng/ntopng-disk-requirements-for-timeseries-and-flows/>`_.


