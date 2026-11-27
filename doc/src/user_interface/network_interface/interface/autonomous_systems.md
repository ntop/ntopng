---
title: "Autonomous Systems"
description: "Autonomous Systems shows all autonomous systems discovered by ntopng. Autonomous Systems require Geolocation enabled."
outline: [2, 3]
lastUpdated: 2026-11-24T12:08:42+01:00
---

<a id="autonomousesystems"></a>

# Autonomous Systems {#autonomous-systems}

Autonomous Systems shows all autonomous systems discovered by ntopng. Autonomous Systems require [Geolocation](/basic_concepts/geolocation.md#geolocation) enabled.

![AS List](../../../img/web_gui_hosts_as_list.png "The Hosts Autonomous Systems Summary Page")

Ntopng uses a Maxmind database to gather information about Autonomous Systems (AS) and based on
this it groups hosts belonging to the same AS. AS number 0 contains all hosts having private IP addresses.

It is possible to tell ntopng which ASNs are your own, which ones belong to your customers, and which ones
are simply relevant for your business: see [ASN Configuration](/asmode/configuration.md#asnconfiguration) for the configuration details.

The page has two tabs: *Overview*, with the chart of the top Autonomous Systems and the table, and *Historical Data*,
with the Autonomous System timeseries of the interface. *Historical Data* is greyed out until Autonomous System
timeseries are enabled in *Settings* > *Preferences* > *Timeseries*.

When ClickHouse is enabled, the time picker at the top of the page sets the period of both the chart and the table.
The page opens on the last 12 hours. You can choose another preset, `Live`, or any start and end date.

The filters above the chart apply to both the chart and the table:

- *ASN Filter*: all the ASNs, or only your ASNs, your customers ASNs, the relevant remote ASNs or the other ones
  (see [ASN Configuration](/asmode/configuration.md#asnconfiguration))
- *Interface Role*: the traffic seen on IX, peering or transit SNMP interfaces. Needs Enterprise M

*Clear filters* sets all of them back to their default.

The chart (when the timeseries are enabled, Enterprise license) shows the top active Autonomous Systems over time.

When `Live` is selected (or when ClickHouse is not available), the table below the chart is labeled
`Active ASN Since Startup`: it reports the traffic of each Autonomous System cumulated since ntopng startup,
and it is independent from the time range selected for the chart.

This happens because the Autonomous Systems historical table is built from the data stored in ClickHouse, while the
Timeseries do not require ClickHouse. As a consequence, without ClickHouse the chart can be moved to any time range,
but the table always shows the data collected since ntopng startup.

The name of each Autonomous System links to its RIPEstat and PeeringDB pages (in a new browser tab). The icons
next to the name mark your ASNs, your customers ASNs and the relevant remote ASNs.

The button of the *Actions* column opens the hosts of the Autonomous System. Its menu also has:

- *Flows of this AS*: the live flows, or the historical flows of the selected time range when it is not `Live`
- *Timeseries*
- *Ingress/Egress Stats*: only with flows from an nProbe exporter, not for the private hosts (ASN 0)

Unavailable actions are shown greyed out with the reason (for example, a past time range can show an Autonomous
System that has no active hosts now: its hosts and ingress/egress statistics are not available).

## Timeseries {#timeseries}

![Top ASN Timeseries](../../../img/web_gui_top_asn_ts.png "The Top ASN Timeseries")

::: warning
To be able to see the Timeseries, they must be enabled from the Settings (Timeseries section).
:::

It is possible to access the Autonomous Systems Timeseries in two different ways:

- By clicking on the Action (button) -> Timeseries, in this way the timeseries of the selected AS are shown;
- By clicking on the *Historical Data* tab, in this way all the AS timeseries of the selected Interface are shown;

::: warning
In case many Autonomous Systems are present, the loading of all the Timeseries (second option above) could may take a while
:::

## Ingress/Egress Stats {#ingress-egress-stats}

This page is used to understand, each AS, where it is sending/receiving the traffic.

![AS View](../../../img/web_gui_as_view.png "The Autonomous Systems View")

There are two different Criteria:

- AS View;
- Ingress/Egress Interfaces;

In the first case the statistics of each AS that are talking to other ASes are shown. Also the Transit AS are shown here (for example ASN 174 is talking to ASN 16509 by using ASN 6939 as Transit).
The table shows the same data as the sankey but in a table view (sortable and searchable).

::: info
The table below is available only from Enterprise L license
:::

![AS View](../../../img/web_gui_ingress_egress_interfaces.png "The Autonomous Systems View")

In the second view instead, it's shown from which exporter and interface each AS is sending/receiving traffic.

::: info
The second view is only available if there is at least an exporter sending traffic towards ntopng (see [Using ntopng with nProbe](/using_with_other_tools/nprobe.md#usingntopngwithnprobe))
:::

## Hosts/Flows {#hosts-flows}

All the hosts or flows being part of the selected Autonomous System, are shown on the respective [Hosts](/basic_concepts/hosts.md#hosts) and [Flows](/user_interface/network_interface/flows/flows.md#webguiflows) pages
