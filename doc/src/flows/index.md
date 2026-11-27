---
title: "Flow Collection"
description: "Network devices (routers, switches, firewalls) generate NetFlow, sFlow, IPFIX, or other flow data. However, ntopng is primarily a flow collector,..."
outline: [2, 3]
lastUpdated: 2026-10-21T10:36:08+02:00
---
# Flow Collection {#flow-collection}

Network devices (routers, switches, firewalls) generate NetFlow, sFlow, IPFIX, or other flow data. However, ntopng is primarily a flow collector, analyzer, and visualizer—it's not optimized to act as a high-performance, dedicated flow probe or collector from many devices simultaneously. While ntopng can listen to flows directly in small setups, for any serious, scalable, or feature-rich deployment (especially requiring application identification), nProbe is an essential companion. It handles the "dirty work" of collection and processing, allowing ntopng to excel at visualization and analysis.

- [What nProbe Does](/flows/nprobe.md)
  - [How nProbe and ntopng Work Together](/flows/nprobe.md#how-nprobe-and-ntopng-work-together)
  - [Why nProbe is Often a Necessary Component](/flows/nprobe.md#why-nprobe-is-often-a-necessary-component)
- [Flow Exporters](/flows/exporters.md)
  - [Exporters in ntopng](/flows/exporters.md#exporters-in-ntopng)
  - [Sites](/flows/exporters.md#sites)
- [Exporter Interfaces Bandwidth Usage per Application](/flows/exporters_bandwidth_usage.md)
  - [Requirements](/flows/exporters_bandwidth_usage.md#requirements)
  - [Interface Speed](/flows/exporters_bandwidth_usage.md#interface-speed)
  - [Charts](/flows/exporters_bandwidth_usage.md#charts)
  - [Top Applications Table](/flows/exporters_bandwidth_usage.md#top-applications-table)
- [Using ntopng with nProbe](/using_with_other_tools/nprobe.md)
  - [Exported Flow Fields](/using_with_other_tools/nprobe.md#exported-flow-fields)
  - [Collecting from Multiple Exporters](/using_with_other_tools/nprobe.md#collecting-from-multiple-exporters)
  - [Using Behind a Firewall](/using_with_other_tools/nprobe.md#using-behind-a-firewall)
  - [Collector Passthrough](/using_with_other_tools/nprobe.md#collector-passthrough)
  - [Data Encryption](/using_with_other_tools/nprobe.md#data-encryption)
  - [Tuning](/using_with_other_tools/nprobe.md#tuning)
  - [Quick Start](/using_with_other_tools/nprobe.md#quick-start)
- [Using ntopng with nProbe (Collector Mode)](/using_with_other_tools/nprobe_collector_mode.md)
  - [Use Cases](/using_with_other_tools/nprobe_collector_mode.md#use-cases)

