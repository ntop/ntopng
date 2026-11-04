sFlow/NetFlow Collection
========================

ntopng, in combination with nProbe, can be used to collect
sFlow/NetFlow. The use of ntopng in combination with nProbe is
described in Section :ref:`UsingNtopngWithNprobe`.

sFlow Collection
----------------

An introduction to sFlow and its collection in ntopng is provided
in this blog post:
https://www.ntop.org/nprobe/sflow-collection-and-analysis-with-nprobe-and-ntopng

Supposing that there are sFlow devices - or agents, in the sFlow parlance - exporting sFlow on port 6343 of the host
where ntopng is running, in order to collect such data it's necessary to configure
nProbe to collect flows on port 6343 and ntopng to talk with nProbe:


.. code:: bash

  nprobe -i none -n none --collector-port 6343 --zmq tcp://127.0.0.1:5556
  ntopng -i tcp://127.0.0.1:5556

The ntopng web dashboard will shortly populate with collected data, including top
senders and top destinations, as well as the top layer-7 application protocols
detected from the traffic. Similarly, all the other ntopng pages will populate with data.

sFlow Devices
-------------

When nProbe forwards the sFlow counters of the devices (the sFlow agents), ntopng lists the
devices and their ports. The list is in the `Network` menu, `sFlow Counter Exporters` entry,
which appears once at least one device has been seen:

.. figure:: ../img/advanced_features_sflow_devices_list.jpg
  :align: center
  :alt: sFlow Devices

  List of the Remote sFlow Devices

Each row shows a single sFlow device. If the device is also configured as an
`SNMP device`_, ntopng shows its name, description and location. Click the ⤢ icon next to the
IP address to see the per-interface statistics of the device. The `Actions` button opens the
same interface list; its menu also opens the device traffic timeseries (`Historical Data` tab,
they need the flow exporters timeseries enabled in `Settings > Preferences > Timeseries`) and
the SNMP device, when there is one. The interfaces page lists the ports with status, speed, duplex,
traffic and errors and, when the device is also an SNMP device with the timeseries enabled, the
Counters/SNMP ratio; the `Actions` button of a port opens its charts or its SNMP interface.

.. figure:: ../img/advanced_features_sflow_interfaces_list.jpg
  :align: center
  :alt: sFlow Device Interfaces

  List of the Remote sFlow Device Interfaces

For each interface, ntopng shows the following information:

  - :code:`Index`: the interface numeric index
  - :code:`Name`: the interface name
  - :code:`Chart`: the interface traffic chart, if the "Flow Devices" timeseries
    are enabled
  - :code:`Speed`: the interface speed
  - :code:`Duplex`: interface duplex information, half or full duplex
  - :code:`Status`: the current interface status
  - :code:`Promisc`: if the interface is in the promiscuous mode
  - :code:`In Bytes`: ingress bytes counter of the interface
  - :code:`Out Bytes`: egress bytes counter of the interface
  - :code:`In Errors`: ingress errors packets counter of the interface
  - :code:`Out Errors`: ingress errors packets counter of the interface
  - :code:`Counters/SNMP Ratio`: the ratio between the sFlow counters by the total traffic read via SNMP

NetFlow Devices
---------------

How the Flow/SNMP Ratio is calculated?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The :code:`Flow/SNMP` Ratio column is calculated by dividing the total interface traffic obtained using flows,
by the total traffic of the same interface read via SNMP. As in flow-based analysis non-IP and layer 2 headers are not accounted,
typical ratio values are between 0.8 and 0.9 (i.e. 0.9 means that 90%% of the received traffic as observed via SNMP has been reported in flows).
Ratio is computed using the traffic over the latest 5 minutes, as periodic SNMP walks are performed at 5-minute intervals.
Ratio is only computed when the following conditions are met:

- Flow Device and SNMP timeseries are enabled
- The device selected must support SNMP and must be configured in the SNMP devices page

nProbe Instances
----------------

The `Network` menu, `nProbe` entry, lists the nProbe instances that send flows to the selected
interface, both the ones collecting NetFlow/IPFIX/sFlow from routers and switches (collector mode)
and the ones capturing packets. The page refreshes every 10 seconds.

- The diagram on top shows how the flows go from the exporters through the probes to ntopng.
  `Total Flows` sizes the links by the flows, `Total Drops` by the flows lost. Click a probe or
  an exporter in the diagram to open its details.
- The table shows, for each probe, its version, license, the number of exporters and interfaces,
  and the exported and lost flows and packets. An arrow next to a counter means it grew since
  the previous refresh. Click the ⤢ icon next to a probe to open the details of its host.
- The `Actions` button opens the flow exporters of the probe; its menu also opens their
  interfaces and the probe host.
- The tabs below the title open, besides the probes, all the flow exporters and their interfaces,
  the exporters map, the sites and the probes timeseries (`Historical Data`).

Flow Exporters
--------------

From the nProbe page, the `Actions` button of a probe opens the flow exporters of that probe (the
`nProbe` filter above the table says which one; remove it to see all the exporters), the `Exporters`
tab all of them: the routers and switches that send their flows through the probes. The tabs below
the title switch between:

- `Exporters`: the exporters with their flows, interfaces and the time of the last flow;
- `Interfaces`: the interfaces of all the exporters;
- `Exporters Map`: the exporters on a map (only in ASN mode);
- `Sites`: the traffic exchanged between the sites of the exporters.

Opening an exporter shows its interfaces, its traffic charts (`Historical Data`, they need the flow
exporters timeseries enabled in `Settings > Preferences > Timeseries`) and, for administrators, its
settings (alias and site). `SNMP` in the top right corner opens the SNMP device with the same IP.
The path on top (`nProbe / Exporters / exporter`) leads back to the lists.

Opening an interface of an exporter shows the autonomous systems its traffic goes to and comes from,
its charts and, for administrators, its settings (alias and speeds). When the exporter is also an
SNMP device, the settings are in the SNMP interface page. `Flows` in the top right corner opens the
live flows of the interface.

Exporters Interfaces
--------------------

The `Network` menu, `Exporters/Interfaces Stats` entry, lists the interfaces of all the
flow exporters (the routers and switches that send NetFlow, IPFIX or sFlow flows through nProbe)
seen on the selected interface, with the traffic each one sent and received since ntopng started.

- Click an exporter name to show only its interfaces, or a role (e.g. Transit, Peering) to show
  only the interfaces with that role. The roles are set in the SNMP interface settings. The
  `Role` menu above the table does the same, and `Clear filters` shows everything again.
- Click the ⤢ icon next to an exporter or an interface to open its details.
- The `Actions` button opens the interface overview; its menu also opens the live flows and the
  hosts that went through that interface, and the interface timeseries.

With an Enterprise license a chart above the table shows the traffic of the 7 busiest interfaces
in the last 24 hours, following the same filters. The chart and the timeseries need the flow
exporters timeseries enabled in `Settings > Preferences > Timeseries`; until then the timeseries
action is disabled.

Observation Points
------------------

An observation point is a place of the network where nProbe collects flows, set with the nProbe
option ``--observation-point-id``. The `Network` menu, `Observation Points` entry, appears when at
least one observation point has been seen and lists them with the number of flow exporters, flows,
hosts, the throughput of the last minute and the traffic since ntopng started.

Click the number of exporters to see them (`Exporters` tab): the IP address of each flow exporter
and its name, taken from SNMP when the exporter is also an SNMP device and you are allowed to see the
SNMP data. Click the ⤢ icon next to the IP address to open the exporter interfaces. The `Actions`
button of each row opens the exporter interfaces or the historical flows of that exporter on this
observation point (they need ClickHouse).

The `Actions` button of each row opens:

- the timeseries of the observation point (`Historical Data` tab). They need the observation points
  timeseries enabled in `Settings > Preferences > Timeseries`;
- its historical flows. They need ClickHouse;
- its settings (`Settings` tab, administrators only), where you can give the observation point a
  name (alias), shown next to its id. Leave the name empty to remove it.

.. _`SNMP device`: ../active_monitoring/snmp.html
