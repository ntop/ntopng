---
title: "Mirror/SPAN/TAP Monitoring"
description: "To monitor data from a mirror/SPAN port or from a tap, refer to Monitoring a Port Mirror/TAP."
outline: [2, 3]
lastUpdated: 2025-02-14T18:12:37+01:00
---

<a id="usecasemirrorspantapmonitoring"></a>

# Mirror/SPAN/TAP Monitoring {#mirror-span-tap-monitoring}

To monitor data from a mirror/SPAN port or from a tap, refer to [Monitoring a Port Mirror/TAP](https://www.ntop.org/nprobe/network-monitoring-101-a-beginners-guide-to-understanding-ntop-tools/).

::: info
[PF_RING Zero Copy](https://www.ntop.org/products/packet-capture/pf_ring/pf_ring-zc-zero-copy/) licenses may be required when the traffic is above 1Gbps. In this case, see [Operating ntopng on large networks](/operating_ntopng_on_large_networks.md#operatingntopngonlargenetworks) and blog post [Best Practices for Efficiently Running ntopng](https://www.ntop.org/ntopng/best-practices-for-running-ntopng/).
:::

## nTap Virtual Tap {#ntap-virtual-tap}

[nTap](https://www.ntop.org/guides/ntap/) is ntop's implementation of a remote/virtual/cloud tap natively embedded in ntopng. You can read more about it [here](/advanced_features/interfaces/ntap_interface.md)
