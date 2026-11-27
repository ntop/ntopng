---
title: "Live Captures"
description: "A live capture downloads the traffic of an interface, or of one of its hosts, as a pcap file while the traffic"
outline: [2, 3]
lastUpdated: 2026-11-03T10:58:14+01:00
---

<a id="livecaptures"></a>

# Live Captures {#live-captures}

A live capture downloads the traffic of an interface, or of one of its hosts, as a pcap file while the traffic
is captured. While captures are running, a badge with their number appears in the top bar: click it to open
the *Live Captures* page of the interface.

The page lists the running captures and refreshes every 10 seconds. Each row shows:

- The captured host, or *All* when the whole interface is captured
- The packets captured so far, out of the maximum number of packets of the capture
- When the capture stops, and the time left

Each capture stops by itself at its time limit or packet limit. Administrators can stop it earlier with the
*Stop* button of the row. Users need the permission to download live traffic and pcap files to see this page
(set in *Settings* > *Users*, see [Users](/user_interface/shared/settings/users.md)).
