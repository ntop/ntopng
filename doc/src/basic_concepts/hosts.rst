Hosts
#####

Broadly speaking, ntopng considers an host any IPv4 or IPv6 address for which it has seen some traffic in at least one of the interfaces monitored. Hosts are continuously monitored by ntopng to account for total traffic volume, layer-7 application protocols, and contracted peers, just to name a few.

To give an example, let's consider ntopng is monitoring interface `eth1` with IP address `192.168.2.1` of a desktop that is trying to PING  host `192.168.2.2`. ntopng will see the following packets:

- ICMP echo requests exiting `eth1` with source IP `192.168.2.1` and destination IP `192.168.2.2`
- ICMP echo replies entering `eth1` with source IP `192.168.2.2` and destination IP `192.168.2.1`

As two different IP addresses are seen, ntopng will create, update and make available through the Web GUI two hosts, namely, `192.168.2.1` and `192.168.2.2`. The whole section :ref:`Hosts` of this guide thoroughly discuss all the information that is available for any host.

Local Hosts
-----------

However, not all hosts are handled equally by ntopng. ntopng can be told to treat some hosts with special care. ntopng refers to those hosts as `local hosts`. But why we should tell ntopng to handle some hosts differently from all the others? Basically, to save resources. Indeed, extra work is done by ntopng to collect, extract, and store additional information for local hosts, including visited websites, DNS requests, and historical timeseries of layer-7 application protocols. Therefore, we should avoid letting ntopng do extra work for hosts we do not care with the aim of saving cpu cycles and disk space.

Typically, local hosts coincide with the hosts in the Local Area Network (LAN). A network administrator cares mosts of the hosts he/she is managing, rather than those in the rest of the world. For this reason, a network administrator that is managing a network `10.0.0.0/8` would start ntopng as


.. code:: bash

   ntopng --local-networks 10.0.0.0/8 <plus other options>

All hosts that are non-local are defined as `remote hosts`. The following table briefly summarizes the differences between local and remote hosts.
