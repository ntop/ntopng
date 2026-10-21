.. _ExporterInterfaceBandwidthUsage:

Exporter Interfaces Bandwidth Usage per Application
###################################################

For each interface of a flow exporter, ntopng can report how much of the interface capacity is used by every
application.

Requirements
------------

From the timeseries preferences enable:

- `Flow Exporters and Probes`: creates the exporter and exporter interface timeseries.
- `Flow Exporters L7 Application` set to `Per Application`: creates a timeseries for every application seen on each exporter interface.
- Optionally, set `Flow Exporters and nProbes Timeseries Resolution` to 1 minute to have 1 minute charts (default is 5 minutes).

Interface Speed
---------------

Percentages are calculated using the uplink and downlink speed configured for the exporter interface. The speed can be
configured from the exporter interface page, `Configuration` (gear icon) tab, or from the `Configuration` action of the
exporter interfaces list. When no speed is configured, the interface speed read via SNMP is used, if available, otherwise
1 Gbit is assumed.

.. note::

   The speed is applied when the charts are drawn, so changing it also changes the percentages reported for the past.

Charts
------

The following timeseries are available from the `Timeseries` tab (chart icon) of the exporter interface page:

- `Usage`: uplink and downlink usage of the whole interface, as percentage of the interface speed.
- `Top L7 Applications (bytes)`: stacked traffic (bps) of the top applications.
- `Top L7 Applications Downlink (percentage)` and `Top L7 Applications Uplink (percentage)`: stacked usage of the top
  applications, as percentage of the downlink and uplink interface speed respectively.
- `<application> (bytes)`, in the `Applications` group: traffic (bps) of a single application.
- `<application> (percentage)`, in the `Applications Bandwidth Usage` group: usage of a single application, as percentage of the
  interface speed.

Uplink is the traffic sent (out) by the exporter through the interface, downlink is the traffic received (in) by the exporter
from the interface. Each point is the average usage over the timeseries step (1 or 5 minutes).

Percentages are not stored on disk: they are calculated, when the chart is requested, from the per application timeseries
and the configured interface speed. Hence they do not require any additional disk space and are also available for the data
collected before configuring the interface speed.

Top Applications Table
----------------------

Below the charts, the `Top Applications` table reports, for the selected time interval, the applications seen on the exporter
interface:

- `Sent`, `Received` and `Traffic`: application traffic volume.
- `Traffic Share`: percentage of the interface traffic due to the application.
- `Throughput`: average application throughput.
- `Uplink (Out) Usage` and `Downlink (In) Usage`: average application usage, as percentage of the uplink and downlink
  interface speed.

Clicking on the application name adds the `<application> (percentage)` chart to the page, while the actions allow to jump to
the live and historical flows of the application on the exporter interface.
