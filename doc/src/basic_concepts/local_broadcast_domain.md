---
title: "Local Broadcast Domain"
description: "The [broadcast domain] represents a network segment where all the nodes can reach each other by sending layer 2 broadcast frames."
outline: [2, 3]
lastUpdated: 2025-02-14T18:12:37+01:00
---

# Local Broadcast Domain {#local-broadcast-domain}

The [broadcast domain] represents a network segment where all the nodes can
reach each other by sending layer 2 broadcast frames.
For a network interface, the local broadcast domain is the broadcast domain of that
interface.

Hosts belonging to the local broadcast domain of a network interface
are marked with the ![lbd icon](../img/lbd_icon.png) icon. For such hosts, the MAC address seen by
ntopng corresponds to the actual device MAC address, as opposed to non local
broadcast domain hosts, whose MAC address corresponds to the MAC address of the
router towards the network where they are located.

Local broadcast domain hosts can be usually identified by MAC address, in order
to correctly serialize them in a DHCP network. This can be set from the
[interface configuration settings].

[broadcast domain]: https://en.wikipedia.org/wiki/Broadcast_domain
[interface configuration settings]: /user_interface/network_interface/interface/interfaces.md#settings
