.. _UseCaseProcessesMonitoring:

Processes Monitoring
####################

ntopng has the ability to provide visibility into the processes which are responsible for the generation of traffic flows, when used in combination with nProbe. Process and other process-related metadata is attached to traffic flows. To enable this feature, nProbe should be started with the --agent-mode option as described in :ref:`UsingNtopngWithNprobeAgent`.

Please note this was previously availble through a separate agent application, *nprobe-agent*, which has been replaces by nprobe in agent mode. The old guides are available at:

- `System-Introspected Network and Container Visibility: A Quick Start Guide <https://www.ntop.org/ntop/system-introspected-network-and-container-visibility-a-quick-start-guide/>`_
- `Introducing libebpfflow: packet-less network traffic and container visibility based on eBPF <https://www.ntop.org/announce/introducing-libebpfflow-packet-less-network-traffic-and-container-visibility-based-on-ebpf/>`_ and referenced articles.

