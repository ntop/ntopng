---
title: "SNMP"
description: "A ntopng Enterprise M license or above is required. SNMP (Simple Network Management Protocol) is a standard used to collect and monitor network..."
outline: [2, 3]
lastUpdated: 2026-06-29T11:46:38+00:00
---

<a id="snmp"></a>

# SNMP {#snmp}

::: info
A ntopng Enterprise M license or above is required.
:::

[SNMP (Simple Network Management Protocol)](https://en.wikipedia.org/wiki/Simple_Network_Management_Protocol) is a standard used to collect and monitor network infrastructures.

ntopng has the ability to combine traffic data with SNMP data. This means it periodically pools SNMP devices to fetch information on their status, on the status of their interfaces, and on who's is connected to them and where. It provides an overall visibility of every monitored device, and allowing a drill-down of the monitored data down to every single device interface. Historical charts are available to understand the patterns of traffic across devices and interfaces.

Alerts can be created, for example, when an interface changes its status from up to down, or vice versa.

- [Configuration and Discovery](/user_interface/shared/snmp/configuration.md)
  - [SNMP Import file](/user_interface/shared/snmp/configuration.md#snmp-import-file)
- [Device Monitoring](/user_interface/shared/snmp/monitoring.md)
  - [Network Interfaces](/user_interface/shared/snmp/monitoring.md#network-interfaces)
  - [Interface Roles](/user_interface/shared/snmp/monitoring.md#interface-roles)
  - [Interface Label Format](/user_interface/shared/snmp/monitoring.md#interface-label-format)
  - [Binding MAC Address to Interface](/user_interface/shared/snmp/monitoring.md#binding-mac-address-to-interface)
- [SNMP Usage](/user_interface/shared/snmp/usage.md)
  - [Exclude Interfaces](/user_interface/shared/snmp/usage.md#exclude-interfaces)
- [Interface Similarity](/user_interface/shared/snmp/similarity.md)
- [Network Topology](/user_interface/shared/snmp/topology.md)
- [Device rules](/user_interface/shared/snmp/rules.md)
- [Statistics and Troubleshooting](/user_interface/shared/snmp/statistics_and_troubleshooting.md)
  - [Checking SNMP page](/user_interface/shared/snmp/statistics_and_troubleshooting.md#checking-snmp-page)
  - [Checking Statistics Timeseries](/user_interface/shared/snmp/statistics_and_troubleshooting.md#checking-statistics-timeseries)
  - [Typical Causes of Delayed Polling](/user_interface/shared/snmp/statistics_and_troubleshooting.md#typical-causes-of-delayed-polling)


These blog posts explain in detail how SNMP monitoring in ntopng works, and what are the best practices for its setup:

- <https://www.ntop.org/ntopng/advanced-snmp-monitoring-with-ntopng/>
- <https://www.ntop.org/ntopng/monitoring-network-devices-with-ntopng-and-snmp/>
