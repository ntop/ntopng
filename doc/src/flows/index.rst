Flow Collection
###############

Network devices (routers, switches, firewalls) generate NetFlow, sFlow, IPFIX, or other flow data. However, ntopng is primarily a flow collector, analyzer, and visualizer—it's not optimized to act as a high-performance, dedicated flow probe or collector from many devices simultaneously. While ntopng can listen to flows directly in small setups, for any serious, scalable, or feature-rich deployment (especially requiring application identification), nProbe is an essential companion. It handles the "dirty work" of collection and processing, allowing ntopng to excel at visualization and analysis.

  
.. toctree::
    :maxdepth: 2

    nprobe.rst
    exporters.rst
    exporters_bandwidth_usage.rst
    ../using_with_other_tools/nprobe
    ../using_with_other_tools/nprobe_collector_mode

    
