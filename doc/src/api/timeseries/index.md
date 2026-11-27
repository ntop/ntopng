---
title: "Timeseries API"
description: "The ntopng timeseries framework provides an abstraction over the timeseries databases"
outline: [2, 3]
lastUpdated: 2019-07-24T15:11:01+02:00
---
# Timeseries API {#timeseries-api}

The ntopng timeseries framework provides an abstraction over the timeseries databases
to handle writes and queries in a way that's independent of the specific implementation.

- [Basic Concepts](/api/timeseries/intro.md)
  - [Schema](/api/timeseries/intro.md#schema)
  - [Schema Name](/api/timeseries/intro.md#schema-name)
  - [Metric Types](/api/timeseries/intro.md#metric-types)
  - [Driver](/api/timeseries/intro.md#driver)
- [Exporting Data](/api/timeseries/export.md)
- [Modify an existing Schema](/api/timeseries/change_schema.md)
- [Adding New Metrics](/api/timeseries/adding_new_timeseries.md)
  - [General Overview](/api/timeseries/adding_new_timeseries.md#general-overview)
    - [Case 1: Adding metrics via the ::lua method](/api/timeseries/adding_new_timeseries.md#case-1-adding-metrics-via-the-lua-method)
    - [Case 2: Adding metrics inside a TimeseriesPoint](/api/timeseries/adding_new_timeseries.md#case-2-adding-metrics-inside-a-timeseriespoint)
    - [Case 3: Adding metrics for Lua only objects](/api/timeseries/adding_new_timeseries.md#case-3-adding-metrics-for-lua-only-objects)
  - [Custom Timeseries Scripts](/api/timeseries/adding_new_timeseries.md#custom-timeseries-scripts)
    - [Structure of Custom Timeseries Scripts](/api/timeseries/adding_new_timeseries.md#structure-of-custom-timeseries-scripts)
    - [Example](/api/timeseries/adding_new_timeseries.md#example)
  - [Charting New Metrics](/api/timeseries/adding_new_timeseries.md#charting-new-metrics)
- [Accessing Metrics](/api/timeseries/accessing_metrics.md)
  - [Interface Metrics](/api/timeseries/accessing_metrics.md#interface-metrics)
  - [Host Metrics](/api/timeseries/accessing_metrics.md#host-metrics)
- [Metrics](/api/timeseries/metrics.md)
  - [Interface Metrics](/api/timeseries/metrics.md#interface-metrics)
  - [Device Metrics](/api/timeseries/metrics.md#device-metrics)
  - [Host Metrics](/api/timeseries/metrics.md#host-metrics)
  - [Subnet Metrics](/api/timeseries/metrics.md#subnet-metrics)
  - [VLAN Metrics](/api/timeseries/metrics.md#vlan-metrics)
  - [SNMP Interface Metrics](/api/timeseries/metrics.md#snmp-interface-metrics)
  - [Traffic Profile Metrics](/api/timeseries/metrics.md#traffic-profile-metrics)
  - [Host Pool Metrics](/api/timeseries/metrics.md#host-pool-metrics)
  - [ASN Metrics](/api/timeseries/metrics.md#asn-metrics)
  - [Country Metrics](/api/timeseries/metrics.md#country-metrics)
  - [Flow Device Metrics](/api/timeseries/metrics.md#flow-device-metrics)
  - [Event Exporter Metrics](/api/timeseries/metrics.md#event-exporter-metrics)
  - [Container Metrics](/api/timeseries/metrics.md#container-metrics)
  - [POD Metrics](/api/timeseries/metrics.md#pod-metrics)
  - [Process Metrics](/api/timeseries/metrics.md#process-metrics)
  - [System Metrics](/api/timeseries/metrics.md#system-metrics)
- [Querying Data](/api/timeseries/queries.md)
  - [Number Of Hosts In The Last Minute](/api/timeseries/queries.md#number-of-hosts-in-the-last-minute)
  - [Traffic On An Interface In The Last Minute](/api/timeseries/queries.md#traffic-on-an-interface-in-the-last-minute)
  - [Traffic On An Interface In The Last Hour, Per Minute](/api/timeseries/queries.md#traffic-on-an-interface-in-the-last-hour-per-minute)
  - [Traffic On An Interface In The Last Hour](/api/timeseries/queries.md#traffic-on-an-interface-in-the-last-hour)
- [ts_utils API](/api/timeseries/ts_utils.md)
- [Driver Implementation](/api/timeseries/driver.md)

