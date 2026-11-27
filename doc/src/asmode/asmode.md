---
title: "Using AS Mode"
description: "In AS mode your GUI will be AS-centric, meaning that you will be focusing on AS, routers and network interfaces rather than on IP addresses."
outline: [2, 3]
lastUpdated: 2026-08-27T14:05:53+00:00
---
# Using AS Mode {#using-as-mode}

In AS mode your GUI will be AS-centric, meaning that you will be focusing on AS, routers and network interfaces rather than on IP addresses.

## Dashboard {#dashboard}

The ntopng Dashboard will now display information related to Autonomous Systems, like Top AS, and Autonomous Systems information the user regards as important, like Top Peering Interfaces.

![as mode dashboard](../img/as_mode_dashboard.png)

## AS Page {#as-page}

![AS List](../img/as_list.png "AS List")

In the Authonomous Systems page under the Interface Menu, it is possible to list live/hostorical AS traffic statistics. For each AS the traffic is represented based on its role (e.g. peering vs transit) and distribution (e.g. received vs sent). Clicking on an AS it is possible to see the traffic breakdown divided per router interface (i.e. how the traffic is sent/received for this AS) and AS (i.e. what AS are sending/receiving traffic from the selected AS.

## Flows {#flows}

Since information is now centered around Autonomous Systems, it will be possible to view not only the Source and Destination Autonomous Systems, but also the Transit AS.

::: info
Flows information are moved to the Views menu entry in AS Mode.
:::

![as mode flows](../img/as_mode_flows.png)

By opening the Details of a flow, it will also be possible to see the AS Transit for each Source and Destination.

![as mode flow details](../img/as_mode_flow_details.png)

## BGP Info {#bgp-info}

The BGP routing information provided by the bgp_server (see the nProbe user's guide <https://www.ntop.org/guides/nprobe/>) is reported in several ways:

- For collected flows, BGP information is reported by nProbe to ntopng via ZMQ.

![bgp info](../img/bgp_info.png)

- You can query the RIB (Routing Information base) living inside the bgp_server and see arbitrary routes, including RPKI validation. This can be accessed from the left sidebar Views -> Routing Information base and query the RIB. The best route (according to the BGP protocol) is reported with a badge, and the route is validated via RPKI.

![looking glass](../img/looking_glass.png)

- BGP alerts for monitored prefixes can be visualized inside the alert page of the system interface under the AS tab.
