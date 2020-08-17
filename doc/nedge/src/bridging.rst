Bridge Mode
===========

Bridge mode is the simplest solution to integrate nEdge into an existing network.

Bridge mode requires two network interfaces to be specified:

 - The LAN interface is the interface which will face the clients to protect.

 - The WAN interface is the interface to the outside world, usually to the
   internet gateway.

This logical division allows nEdge to properly identify the clients to monitor
(on the LAN interface) without affecting the rest of the network (on the WAN).

.. figure:: img/bridge_network.png
  :align: center
  :alt: Bridge Network Configuration

  Bridge network configuration

nEdge can be either configured to automatically acquire an IP address in
DHCP client mode or a manually assigned IP address can be provided.
Usually a DHCP server is already available in the network so automatic configuration
can be applied.

VLAN Trunk Bridging
---------------------------------------------

nEdge can also bridge interfaces with VLAN-tagged traffic when it is
configured as a VLAN Trunk bridge.

In VLAN Trunk mode, it's necessary to specify the list of local networks by manually editing the file
`/etc/ntopng/ntopng.conf` via the `-m` option. Policies will only be applied to local hosts, so
this is very important. See `the ntopng documentation`_ for more details.

In VLAN Trunk mode, it's also essential to set up a management address to
reach the device. This should be done before applying the VLAN Trunk mode settings
in order to avoid losing management access. This usually is performed in one of the following ways:

- by using a dedicated network interface (this setup requires at least 3 network interfaces)
- by using a virtual network interface on a VLAN (only 2 network interfaces required)

On Ubuntu 16, the management interface configuration should be written to the
`/etc/network/interfaces.d/nedge_mgmt.conf` configuration file. Here is an example
on how to set up a virtual network interface for the VLAN case above (the dedicated
interface case is trivial):

.. code:: bash

 $ cat /etc/network/interfaces.d/nedge_mgmt.conf
 # https://bugs.launchpad.net/ubuntu/+source/ifupdown/+bug/1643063
 # must specify the pre-up command and the vlan-raw-device

 auto br0.86
 iface br0.86 inet static
      pre-up /sbin/ip link add link br0 name br0.86 type vlan id 86
      vlan-raw-device br0
      address 10.10.10.1
      netmask 255.255.255.0

The configuration above specifies to create a virtual interface br0.86 with VLAN
86. The VLAN id (86 in this example) should match one of the VLAN ids flowing through
the VLAN trunk. Such virtual interface will be created after reboot. When the
VLAN Trunk mode is running on the nEdge device, the administrator can connect to the
management IP (10.10.10.1 in this example) by configuring a network interface on the same
network (10.10.10.0/24 in this example). For example:

.. code:: bash

   $ ifconfig eth0 10.10.10.99 netmask 255.255.255.0

The switch port connected to the administrator eth0 interface must be tagged with the same
VLAN id configured in the `nedge_mgmt.conf` file (86 in this example) in order for
this to work.

.. warning::

   Due to an open issue (https://github.com/ntop/ntopng/issues/2117) users must be
   very cautios when configuring blocking policies in this mode as they will affect the
   management interface as well and possibly block management access.

See management_ for a detailed description of how the network
configuration is handled by nEdge.

.. warning::

   Overlapping IP addresses across multiple VLANs are not handled. nEdge will
   show them as a single host

   
.. warning::

   Neither the CaptivePortal nor the DNS enforcement is performed in this mode.


Full Transparent Mode
---------------------

In order to set up nEdge to be fully transparent, which means that it won't alter
network traffic but only provide a pass/drop verdict for client packets, some
care should be taken.

- Make sure the `Enforce Global DNS` is disabled from the DNS settings page.

- Disalbe the Captive Portal the can alter packets in order to perform devices authentication.

.. _management: management.html
.. _`the ntopng documentation`: https://www.ntop.org/guides/ntopng/basic_concepts/hosts.html#local-hosts

Supported Ethernet Protocols
----------------------------

While running in bridge mode, nEdge supports the following Ethernet protocols:

- ARP
- IPv4

Other Ethernet protocols (like PPPoE) are *blocked* as nEdge does not handle them.
