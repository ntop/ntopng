.. _SNMP:

SNMP
====

ntopng (Enterprise) is able to perform SNMP monitoring, providing
an overall visibility of every monitored device, and allowing a
drill-down of the monitored data down to every single device
interface.

Historical charts are available to understand the patterns of traffic
across devices and interfaces.

Alerts can be created, for example, when an interface changes its status
from up to down, or vice versa.

These blog posts explain in detail how SNMP monitoring in ntopng
works, and what are the best practices for its setup:

- https://www.ntop.org/ntopng/advanced-snmp-monitoring-with-ntopng/
- https://www.ntop.org/ntopng/monitoring-network-devices-with-ntopng-and-snmp/

LLDP
----

ntopng supports the Link Layer Discovery Protocol (LLDP). LLDP is a network protocol used to dynamically build network topologies and identify network device neighbors. LLDP can be enabled on network devices such as switches and routers. ntopng periodically uses SNMP to periodically read LLDP information from devices having LLDP enabled. Polled information is then used to build an adjacency graph. The adjacency graph is interactive and is shown in the GUI.

Additional details are available at:

- https://www.ntop.org/ntopng/exploring-physical-network-topologies-using-ntopng/
