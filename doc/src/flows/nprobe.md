---
title: "What nProbe Does"
description: "Think of nProbe as a versatile flow agent and translator that sits between your network devices and ntopng. Its key functions are:"
outline: [2, 3]
lastUpdated: 2026-02-04T18:27:48+01:00
---
# What nProbe Does {#what-nprobe-does}

Think of nProbe as a versatile flow agent and translator that sits between your network devices and ntopng. Its key functions are:

- Flow Collection & Export Protocol Termination:
  It listens for flow exports from network hardware (NetFlow v5/v9, IPFIX, sFlow).
  It can handle exports from hundreds of devices, acting as a central, scalable collector. ntopng alone isn't designed to scale to that level of direct ingestion.
- Flow Probing / Generation:
  It can also act as a software probe itself. By sniffing live traffic from a network interface (or a PCAP file), it can generate flow records from raw packets, just like a hardware router does. This is crucial if your network devices don't support flow export.
- Protocol Translation & Normalization:
  This is a critical function. nProbe converts any incoming flow format (sFlow, NetFlow v5, NetFlow v9, etc.) into a single, unified format (typically NetFlow v9 or IPFIX) that ntopng understands and expects.

It "cleans" and normalizes the data, ensuring consistency before it reaches ntopng.
Flow Enrichment & Augmentation:

nProbe can add valuable metadata to flow records before passing them to ntopng. This includes:

- GeoIP Information: Adding country, city, AS number for source/destination IPs.
- Deep Packet Inspection (DPI): Identifying the actual application (e.g., Facebook, Netflix, Zoom) based on packet signatures, not just port numbers. (This is a licensed feature in the full version).
- VLAN/MPLS tagging: Preserving or adding layer 2 information.
- Flow Filtering & Sampling Aggregation:

It can filter flows (e.g., "ignore all DNS traffic") before sending them forward, reducing load on ntopng.
It can handle and even re-sample sampled flows (like sFlow) to provide more accurate volume estimates.
Load Distribution & Fan-out:

A single nProbe instance can collect from many sources and fan out the processed flows to multiple destinations (e.g., multiple ntopng instances, or other tools like Elasticsearch).

## How nProbe and ntopng Work Together {#how-nprobe-and-ntopng-work-together}

- Devices send raw flow data to the nProbe IP address and port.
- nProbe receives, normalizes, enriches (GeoIP, DPI), and filters this data.
- nProbe then forwards the cleaned, unified flow stream to ntopng. This is often done using a lightweight, efficient protocol called ZMQ (ZeroMQ), which is ntop's preferred method, but it can also use NetFlow v9/IPFIX.
- ntopng receives the single, clean stream from nProbe.

It then focuses on its core jobs:

- Real-time visualization in the web GUI.
- Time-series analysis and historical reporting.
- Alerting on anomalies and thresholds.
- Storing aggregated data for trends.

## Why nProbe is Often a Necessary Component {#why-nprobe-is-often-a-necessary-component}

- Scalability: For environments with more than a handful of flow exporters, using nProbe as a collector is mandatory. ntopng's native collector is not designed for large-scale, multi-device ingestion.
- Hardware Support: If your network hardware doesn't support flow export, nProbe is the only way to generate flows for ntopng by sniffing traffic directly.
- Protocol Support: Some legacy formats (like NetFlow v5) are not natively streamed to ntopng. nProbe must translate them.
- Feature Dependency: Critical features like Deep Packet Inspection (application identification) are performed by nProbe, not ntopng. If you need to see "Facebook" or "TikTok" as an application in your ntopng dashboard, you must use nProbe with a valid license for its DPI plugin.
- Architectural Flexibility: It allows you to place a collector (nProbe) in a remote network segment and forward only the processed data to a central ntopng server.
