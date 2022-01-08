Interfaces vs View Interfaces
#############################

There are cases when multipe interfaces need to be aggregated together with the aim of performing traffic analyses on the aggregate.

For example, when RSS is used to process packets across multiple queues, a re-aggregation is useful to obtain visibility of the whole traffic and not just a subset of it.

In the following example, a :code:`view:` interface is created to aggregate packets from two :code:`eth1` RSS queues processed using PF_RING Zero Copy.

.. code::

	./ntopng -i zc:eth1@0  -i zc:eth1@1  -i view:zc:eth1@0,zc:eth1@1

If you do not want to list all interfaces you can use the shortcut :code:`view:all` to tell ntopng to create a view interface from all configured interfaces. The above example will then become:

.. code::

	./ntopng -i zc:eth1@0  -i zc:eth1@1  -i view:all

However, view interfaces come with some visibility limitations if compared to other interfaces. This means they don't have all traffic data that is normally available for regular interfaces. For example, view interfaces don't have:

  - MAC addresses and everything related to MAC addresses
  - Packet size distribution (up to 128, up to 256, ...)
  - TCP Flags / ARP Distribution

A comprehensive list of all the limitations is at  `this page <https://github.com/ntop/ntopng/issues/3383>`_.

Using interfaces views also reduces the data available on *viewed* interfaces. For example, using :code:`-i view:zc:eth1@0,zc:eth1@1` will automatically reduce the data kept for :code:`zc:eth1@0` and :code:`zc:eth1@1`, respectively.

Viewed interfaces only have flows. All other network elements are kept for the view interface only. A non-exhaustive list of network elements that are not present on viewed interfaces but are kept on view interface is:

  - Hosts and historical hosts data
  - Autonomous Systems
  - VLANs

The rationale behind this is:

  - Technical, as keeping most of the network elements only in the view greatly reduces the overall memory footprint
  - Practical, to avoid keeping partial data (e.g., the same host :code:`1.1.1.1` can be seen on two interfaces but, since a view is used, only it overall aggregated data is assumed to be relevant).
