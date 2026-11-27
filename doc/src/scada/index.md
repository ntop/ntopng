---
title: "Industrial Monitoring"
description: "Operational Technology (OT) refers to computing systems that are used to manage industrial operations. ntopng supports some Industrial Control Systems..."
outline: [2, 3]
lastUpdated: 2026-11-04T10:23:56+01:00
---
# Industrial Monitoring {#industrial-monitoring}

Operational Technology (OT) refers to computing systems that are used to manage industrial operations. ntopng supports some Industrial Control Systems (ICS), often managed via Supervisory Control and Data Acquisition (SCADA) systems. Via nDPI it can detect protocols such as Modbus, S7Comm, PROFINET, IEC 60870-5-104 and BACnet. In addition to this, ntopng provides an extensive analysis of some of these protocols.

ntopng is a monitoring tool able to detect "generic" and behavioural issues that can disrupt an OT network. They include (but are not limited to):

- New device detection and invalid MAC/IP combinations
- Device traffic behavioural analysis (e.g. traffic misbehaving, peaks in traffic)
- New protocols and services: detect when a device changes the provided services (e.g. an HTTPS server is spawned) or a new protocol is used as client

In addition to the above services, specific protocols are supported in detail. This section lists the main protocols for which ntopng provides advanced monitoring features.

- [1. ModbusTCP](/scada/modbus.md)
  - [1.1. Flow Information](/scada/modbus.md#flow-information)
  - [1.2. Behavioural Checks](/scada/modbus.md#behavioural-checks)
- [2. S7Comm](/scada/s7comm.md)
  - [2.1. Flow Information](/scada/s7comm.md#flow-information)
  - [2.2. Behavioural Checks](/scada/s7comm.md#behavioural-checks)
- [3. PROFINET](/scada/profinet.md)
  - [3.1. Flow Information](/scada/profinet.md#flow-information)
  - [3.2. Behavioural Checks](/scada/profinet.md#behavioural-checks)
- [4. IEC 60870-5-104](/scada/IEC60870-5-104.md)
- [5. Custom Detections](/scada/custom_detections.md)
  - [5.1. Where the data comes from](/scada/custom_detections.md#where-the-data-comes-from)
  - [5.2. How to use it](/scada/custom_detections.md#how-to-use-it)
  - [5.3. Alerts](/scada/custom_detections.md#alerts)
  - [5.4. Writing a script](/scada/custom_detections.md#writing-a-script)

