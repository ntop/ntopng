---
title: "Host Pools"
description: "In ntopng the Host Pools provide a powerful way to group together different hosts."
outline: [2, 3]
lastUpdated: 2025-02-14T18:12:37+01:00
---

<a id="basicconceptshostpools"></a>

# Host Pools {#host-pools}

In ntopng the Host Pools provide a powerful way to group together different hosts.
Host Pools are defined on a network interface basis. An host pool can contain the
following entities:

- Single IP addresses, which match a single host by IPv4/IPv6 address
- MAC address, which match a single host by MAC address
- Network address, which matches all the hosts whose IPv4/IPv6 address belongs
  to the given network (specified in CIDR format).

A VLAN id can also be specified to match the hosts of a specific VLAN.

After grouping hosts by the means of host pools, it is possible to view the
grouped statistics and timeseries. For more information, check out the relevant
[documentation section].

[documentation section]: /user_interface/network_interface/interface/host_pools.md
