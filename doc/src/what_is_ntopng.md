---
title: "What is ntopng"
description: "ntopng is a web-based traffic monitoring application able to: The main difference between ntopng and a traffic collector, is that ntopng not only reports..."
outline: [2, 3]
lastUpdated: 2025-07-14T10:10:37+02:00
---
# What is ntopng {#what-is-ntopng}

ntopng is a web-based traffic monitoring application able to:

- Passive monitor traffic by passively capturing network traffic
- Collect network flows (NetFlow, sFlow and IPFIX)
- Actively monitor selected network devices
- Monitor a network infrastructure via SNMP

The main difference between ntopng and a traffic collector, is that ntopng not only reports traffic statistics but it also analizes the traffic, draws conclusions on observed traffic type and reports cybersecurity metrics.

![ntopng main components](./img/ntopng-main-components.png)

## Releases and Features {#releases-and-features}

ntopng development lifecycle is typically 6 to 9 months. The history of changes and features implemented by every release, is available on its [Changelog](https://github.com/ntop/ntopng/blob/dev/CHANGELOG.md).

Please stay tuned and follow the ntop blog (<http://blog.ntop.org>) for all the latest news or visit the ntop
GitHub page at <http://github.com/ntop>.

## Basic Concepts & Use Cases {#basic-concepts-use-cases}

- [Basic Concepts](/basic_concepts/index.md)
  - [Geolocation](/basic_concepts/geolocation.md)
    - [Introduction](/basic_concepts/geolocation.md#introduction)
    - [Using MaxMind geolocation in ntopng](/basic_concepts/geolocation.md#using-maxmind-geolocation-in-ntopng)
    - [Using geolocation on Raspberry Pi OS (Raspbian)](/basic_concepts/geolocation.md#using-geolocation-on-raspberry-pi-os-raspbian)
    - [How to use MaxMind instead of DB-IP?](/basic_concepts/geolocation.md#how-to-use-maxmind-instead-of-db-ip)
    - [Using geolocation when ntopng-data is not available](/basic_concepts/geolocation.md#using-geolocation-when-ntopng-data-is-not-available)
    - [Upgrading from a previous version of ntopng-data](/basic_concepts/geolocation.md#upgrading-from-a-previous-version-of-ntopng-data)
  - [Network Interfaces](/basic_concepts/interfaces.md)
  - [System Interface](/basic_concepts/system_interface.md)
  - [Hosts](/basic_concepts/hosts.md)
    - [Local Networks](/basic_concepts/hosts.md#local-networks)
  - [Host Pools](/basic_concepts/host_pools.md)
  - [Statistics](/basic_concepts/stats.md)
    - [Rates](/basic_concepts/stats.md#rates)
  - [Alerts](/basic_concepts/alerts.md)
    - [Behavioral Alerts](/basic_concepts/alerts.md#behavioral-alerts)
    - [User Activities](/basic_concepts/alerts.md#user-activities)
    - [Severity](/basic_concepts/alerts.md#severity)
    - [Entities](/basic_concepts/alerts.md#entities)
    - [Type](/basic_concepts/alerts.md#type)
    - [Recipients](/basic_concepts/alerts.md#recipients)
    - [Alerts Explorer](/basic_concepts/alerts.md#alerts-explorer)
  - [Timeseries](/basic_concepts/timeseries.md)
    - [RRD Driver](/basic_concepts/timeseries.md#rrd-driver)
    - [InfluxDB Driver](/basic_concepts/timeseries.md#influxdb-driver)
    - [ClickHouse Driver](/basic_concepts/timeseries.md#clickhouse-driver)
    - [Timeseries Configuration](/basic_concepts/timeseries.md#timeseries-configuration)
    - [Network Matrix Timeseries](/basic_concepts/timeseries.md#network-matrix-timeseries)
  - [Scripts and Checks](/basic_concepts/scripts.md)
  - [Local Broadcast Domain](/basic_concepts/local_broadcast_domain.md)
  - [Disk Space Requirements](/basic_concepts/disk_space.md)
    - [Estimating Space Requirements](/basic_concepts/disk_space.md#estimating-space-requirements)
    - [Flows](/basic_concepts/disk_space.md#flows)
- [Use Cases](/use_cases/index.md)
  - [Mikrotik](/use_cases/mikrotik.md)
  - [Suricata](/use_cases/suricata.md)
  - [Monitoring Large Networks](/use_cases/large_networks.md)
  - [Processes Monitoring](/use_cases/processes_monitoring.md)
  - [SNMP Monitoring](/use_cases/snmp_monitoring.md)
  - [Infrastructure Monitoring](/use_cases/infrastructure_monitoring.md)
    - [Infrastructure Dashboard](/use_cases/infrastructure_monitoring.md#infrastructure-dashboard)
  - [Netflow/sFlow Monitoring](/use_cases/netflow_sflow_monitoring.md)
  - [Mirror/SPAN/TAP Monitoring](/use_cases/mirror_tap_monitoring.md)
    - [nTap Virtual Tap](/use_cases/mirror_tap_monitoring.md#ntap-virtual-tap)
  - [Monitoring Multiple Locations](/use_cases/multiple_locations_monitoring.md)

