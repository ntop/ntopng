Local Broadcast Domain
######################

The `broadcast domain`_ represents a network segment where all the nodes can
reach each other by sending layer 2 broadcast frames.
For a network interface, the local broadcast domain is the broadcast domain of that
interface.

Hosts belonging to the local broadcast domain of a network interface
are marked with the |lbd_icon| icon. For such hosts, the MAC address seen by
ntopng corresponds to the actual device MAC address, as opposed to non local
broadcast domain hosts, whose MAC address corresponds to the MAC address of the
router towards the network where they are located.

Local broadcast domain hosts can be usually identified by MAC address, in order
to correctly serialize them in a DHCP network. This can be set from the
`interface configuration settings`_.

.. |lbd_icon| image:: ../img/lbd_icon.png
.. _`broadcast domain`: https://en.wikipedia.org/wiki/Broadcast_domain
.. _`interface configuration settings`: ../web_gui/interfaces.html#settings
