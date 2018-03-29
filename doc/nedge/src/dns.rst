DNS
===

nEdge can enforce a specific DNS server to be used by the LAN devices.
nEdge ships with some preset of secure DNS servers, which provide an
additional security against malware sites.

Global DNS
----------

The `Global DNS` is the DNS server used in the following cases:

  - When the DHCP server is enabled in routing mode, it will configure the
    non child-safe clients to use these DNS servers
  - By the nEdge device for interfaces configured in static address mode

.. figure:: img/global_dns.png
  :align: center
  :alt: Global DNS

  Global DNS configuration

If the `Enforce Global DNS` option is set, nEdge will enforce the use of the
specified `Global DNS` even if the clients manually change their DNS servers.

Secure DNS servers can be chosen from the provided presets or be specified manually.

Child Safe
----------

The `Child Safe` DNS is the DNS used for users which are marked with the `Child Safe`
option.

.. figure:: img/child_dns.png
  :align: center
  :alt: Child DNS

  Child DNS configuration

Such DNS can protect the children from inappropriate adult content.

**Note**: nEdge will always enforce the use of such a DNS for all the child safe users,
even if they manually change their DNS servers.
