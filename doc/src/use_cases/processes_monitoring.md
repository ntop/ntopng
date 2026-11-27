---
title: "Processes Monitoring"
description: "ntopng has the ability to provide visibility into the processes which are responsible for the generation of traffic flows, when used in combination with..."
outline: [2, 3]
lastUpdated: 2022-08-18T10:54:29+02:00
---

<a id="usecaseprocessesmonitoring"></a>

# Processes Monitoring {#processes-monitoring}

ntopng has the ability to provide visibility into the processes which are responsible for the generation of traffic flows, when used in combination with nProbe. Process and other process-related metadata is attached to traffic flows. To enable this feature, nProbe should be started with the --agent-mode option as described in [Using ntopng with nProbe Agent](/using_with_other_tools/nprobeagent.md#usingntopngwithnprobeagent).

Please note this was previously availble through a separate agent application, *nprobe-agent*, which has been replaces by nprobe in agent mode. The old guides are available at:

- [System-Introspected Network and Container Visibility: A Quick Start Guide](https://www.ntop.org/ntop/system-introspected-network-and-container-visibility-a-quick-start-guide/)
- [Introducing libebpfflow: packet-less network traffic and container visibility based on eBPF](https://www.ntop.org/announce/introducing-libebpfflow-packet-less-network-traffic-and-container-visibility-based-on-ebpf/) and referenced articles.
