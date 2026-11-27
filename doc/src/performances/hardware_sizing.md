---
title: "Hardware Sizing"
description: "Indications on process, memory and disk required are given below for networks with three different sizes."
outline: [2, 3]
lastUpdated: 2023-03-28T11:18:28+02:00
---
# Hardware Sizing {#hardware-sizing}

Indications on process, memory and disk required are given below for networks with three different sizes.

## Network Size {#network-size}

|  | Small Network | Medium Network | Large Network |
|---|---|---|---|
| Traffic | &lt; 100Mbps | Between 100Mbps and 1Gbps | Above 1Gbps |
| Active Hosts | Hundredths | Thousands | Hundreds of thousands |
| Active Flows | Thousands | Hundreds of thousands | Millions |

::: info
On large networks, special extra configuration is required as explained in [Operating ntopng on large networks](/operating_ntopng_on_large_networks.md#operatingntopngonlargenetworks).
:::

## Processor and Memory {#processor-and-memory}

|  | Small Network | Medium Network | Large Network |
|---|---|---|---|
| Processor | 2cores+ | 4cores+ | 8cores+ |
| Memory | 2GB+ | 4GB+ | 16GB+ |

## Disk {#disk}

See [ntopng Disk Requirements for Timeseries and Flows](https://www.ntop.org/ntopng/ntopng-disk-requirements-for-timeseries-and-flows/).
