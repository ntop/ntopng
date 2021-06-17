.. _UseCaseProcessesMonitoring:

Processes Monitoring
####################

On Linux, ntopng has the ability to provide visibility into the processes which are responsible for the generation of traffic flows. Process and other process-related metadata is attached to traffic flows. To enable this feature, ntopng needs to be used in combination with nProbe Agent (see :ref:`UsingNtopngWithNprobeAgent`). For additional details, please refer to blog posts:

- `System-Introspected Network and Container Visibility: A Quick Start Guide <https://www.ntop.org/ntop/system-introspected-network-and-container-visibility-a-quick-start-guide/>`_
- `Introducing libebpfflow: packet-less network traffic and container visibility based on eBPF <https://www.ntop.org/announce/introducing-libebpfflow-packet-less-network-traffic-and-container-visibility-based-on-ebpf/>`_ and referenced articles.

.. note::

	An nProbe Agent license is required.
