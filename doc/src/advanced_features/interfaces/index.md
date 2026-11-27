---
title: "Interfaces"
description: "ntopng uses interfaces to perform its tasks. One or more interfaces are required by ntopng to properly execute. Interfaces are specified to ntopng using..."
outline: [2, 3]
lastUpdated: 2025-02-14T18:12:37+01:00
---

<a id="interfaces"></a>

# Interfaces {#interfaces}

ntopng uses interfaces to perform its tasks. One or more interfaces are required by ntopng to properly execute. Interfaces are specified to ntopng using option `-i`. Multiple types of interface exist.

This section introduces the concept of interfaces and discusses differences, pros and cons of each interface type.

- [3.1. Packet vs ZMQ Interfaces](/advanced_features/interfaces/packet_vs_zmq.md)
  - [3.1.1. Packet Interfaces](/advanced_features/interfaces/packet_vs_zmq.md#packet-interfaces)
  - [3.1.2. ZMQ Interfaces](/advanced_features/interfaces/packet_vs_zmq.md#zmq-interfaces)
  - [3.1.3. Traffic Analysis: Differences](/advanced_features/interfaces/packet_vs_zmq.md#traffic-analysis-differences)
  - [3.1.4. Packet vs ZMQ: Which One to use?](/advanced_features/interfaces/packet_vs_zmq.md#packet-vs-zmq-which-one-to-use)
- [3.2. View Interfaces](/advanced_features/interfaces/view_interfaces.md)
- [3.3. Interfaces vs View Interfaces](/advanced_features/interfaces/interfaces_vs_view_interfaces.md)
- [3.4. Interfaces Disaggregation](/advanced_features/interfaces/dynamic_interfaces_disaggregation.md)
  - [3.4.1. Dynamic Disaggregation](/advanced_features/interfaces/dynamic_interfaces_disaggregation.md#dynamic-disaggregation)
  - [3.4.2. Custom Disaggregation](/advanced_features/interfaces/dynamic_interfaces_disaggregation.md#custom-disaggregation)
- [3.5. Using nTap as Virtual Tap with ntopng](/advanced_features/interfaces/ntap_interface.md)
  - [3.5.1. ntopng Enterprise L](/advanced_features/interfaces/ntap_interface.md#ntopng-enterprise-l)
  - [3.5.2. All Other ntopng Editions](/advanced_features/interfaces/ntap_interface.md#all-other-ntopng-editions)

