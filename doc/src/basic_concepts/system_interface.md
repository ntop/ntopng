---
title: "System Interface"
description: "ntopng monitoring capabilities are not limited to the network traffic. ntopng monitors also:"
outline: [2, 3]
lastUpdated: 2025-02-14T18:12:37+01:00
---

<a id="basicconceptsysteminterface"></a>

# System Interface {#system-interface}

ntopng monitoring capabilities are not limited to the network traffic. ntopng monitors also:

- The system on top of which ntopng is running (e.g, disk space and load)
- Status and health of the current ntopng instance (with a Redis Monitor and an InfluxDB Monitor)

Monitoring features above are performed by the system interface. The system interface is available in the ntopng interfaces dropdown menu as any other interface.

Network monitoring tasks that are not specific to a single interface are performed by the system interface as well. Indeed, the system interface features:

- An [Active Monitoring](/user_interface/shared/monitoring/active_monitoring.md#activemonitoring) to actively monitored hosts in the network
- [infrastructuremonitoring](/use_cases/infrastructure_monitoring.md#infrastructuremonitoring) to actively monitor multiple ntopng instances
- The monitoring of [SNMP] devices

[snmp]: /user_interface/shared/snmp/index.md
