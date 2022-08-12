.. _UseCaseMirrorSPANTAPMonitoring:

Mirror/SPAN/TAP Monitoring
##########################

To monitor data from a mirror/SPAN port or from a tap, refer to `Monitoring a Port Mirror/TAP <https://www.ntop.org/nprobe/network-monitoring-101-a-beginners-guide-to-understanding-ntop-tools/>`_.

.. note::

	`PF_RING Zero Copy <https://www.ntop.org/products/packet-capture/pf_ring/pf_ring-zc-zero-copy/>`_ licenses may be required when the traffic is above 1Gbps. In this case, see :ref:`OperatingNtopngOnLargeNetworks` and blog post `Best Practices for Efficiently Running ntopng <https://www.ntop.org/ntopng/best-practices-for-running-ntopng/>`_.


nTap Virtual Tap
================

`nTap <https://www.ntop.org/guides/ntap/>`_ is ntop's implementation of a remote/virtual/cloud tap natively embedded in ntopng. You can read more about it `here <../interfaces/ntap_interface.html>`_
