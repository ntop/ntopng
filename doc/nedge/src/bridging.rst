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

Full Transparent Mode
---------------------

In order to set up nEdge to be fully transparent, which means that it won't alter
network traffic but only provide a pass/drop verdict for client packets, some
care should be taken.

- By default, nEdge will change clients DNS traffic to use the configured
  DNS servers. In order to avoid this, the `Enforce Global DNS`
  option should be disabled from the DNS settings page.

- Captive Portal can alter packets in order to request devices authentication.
  It is necessary to disable it for a transparent mode.
