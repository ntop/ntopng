.. _OperatingNtopngOnLargeNetworks:

Operating ntopng on large networks
==================================

ntopng, in its default configuration, works out-of-the-box for
most of the users. Home networks and small- to medium-sized corporate
networks rarely require changes and optimizations to the ntopng
configuration.

However, under some circumstances, a fine-tuning of the configuration could
prove to be very helpful. There are some clear indicators that suggest
a tuning is required. Those indicators are discussed below.

Red Badges
----------

Sometimes, badges shown in the bottom-right corner of ntopng can turn
into red. A red hosts badge indicates ntopng has not enough room to
handle all the hosts. Similarly, a red flows badge indicates ntopng has
not enough room to handle all the flows.

To increase the maximum number of hosts and flows handled by ntopng,
it is possible to use options :code:`-x` and :code:`-X`,
respectively. It is recommended to use values that are much
greater than the actual number of hosts and flows.

For example, assuming that ntopng has, on average, 10000 hosts and
20000 flows, one could safely specify :code:`-x=100000` and
:code:`-X=200000` to make sure there always be enough room.

Packet Drops
------------

When ntopng drops packets, it means that it cannot keep up with the
rate at which packets are entering the NIC being monitored. One first
check to perform is to disable the "Idle Local Hosts Cache" preference from the
ntopng "Cache Settings", which has an high impact on the packet capture
thread due to its interactions with Redis for newly created hosts.

If the above change does not solve the packet drops issue, one should
consider operating PF_RING Zero Copy
(ZC), and even use RSS to let multiple thread handle the incoming
traffic. The configuration of PF_RING ZC and RSS fall outside
the scope of this guide. Additional information can be found at the
following links:

- https://www.ntop.org/guides/pf_ring/zc.html
- https://www.ntop.org/guides/pf_ring/rss.html

When RSS is enabled, the traffic will be spread across multiple virtual
interfaces. View Interfaces can be used in order to aggregate the traffic
back into a single interface, check out
https://www.ntop.org/guides/ntopng/advanced_features/view_interfaces.html .

Additional Tuning
-----------------

We recommend the user interested in fine-tuning ntopng to refer to
this blog post for additional tips and tricks:
https://www.ntop.org/ntopng/best-practices-for-running-ntopng/.


