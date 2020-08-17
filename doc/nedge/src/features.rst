Features
========

Here is a list of some of the unique features nEdge provides:

- Secure DNS to block malicious domains
- Provide fair bandwidth share between LAN devices
- Block/throttle undesired protocols
- Create users to group device together and assign block/bandwidth limit policies
- Protect children from inappropriate content
- Define per-user and per-protocol time/traffic quotas
- Define customized routing policies with failover and load balance
- Assisted monitoring device configuration

Moreover, since nEdge is based on the well known monitoring software ntopng_, a lot more
interesting features are available:

- Malware hosts detection by the means of blacklists
- Active discovery and classification of the active devices in the network
- Accurate L7 traffic classification thanks to nDPI
- Many traffic insights, for example per user, country, operating system views
- Per host/device flows view
- Traffic reports and charts of the past traffic
- Alerts system with slack integration

Some of the ntopng features, however, are *not* available in nEdge:

- No flow data export/historical explorer (e.g. MySQL and ElasticSearch export)
- No traffic profiles
- No ability to read data from nProbe (e.g. NetFlow/sFlow data)
- No LDAP integration
- No SNMP devices monitoring

.. warning::

   Currently, IPv6 traffic is neither handled nor forwarded by
   nEdge. IPv6 traffic is never forwarded to LAN or WAN devices.

.. _ntopng: http://www.ntop.org/products/traffic-analysis/ntop/
