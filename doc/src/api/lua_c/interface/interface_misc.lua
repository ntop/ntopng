--! @brief Set the *active interface* by using the interface id.
--! @param id the interface id.
--! @return the interface name on success, nil otherwise.
function interface.setActiveInterfaceId(int id)

--! @brief Get the available ntopng network interfaces.
--! @return a table containing (ifid -> ifname) mappings.
function interface.getIfNames()

--! @brief Get the first available interface ID.
--! @return the first interface ID.
function interface.getFirstInterfaceId()

--! @brief Get the currently selected interface ID.
--! @return the current interface ID.
function interface.getId()

--! @brief Set the *active interface* by using the interface name.
--! @param ifname the interface name.
function interface.select(string ifname)

--! @brief Check if the network interface has seen VLAN traffic.
--! @return true if the interface has VLANs, false otherwise.
function interface.hasVLANs()

--! @brief Check if the network interface is capturing eBPF events.
--! @param true if the interface has eBPF, false otherwise.
function interface.hasEBPF()

--! @brief Get statistics including nDPI protocol information of the network interface/a specific host.
--! @param host_ip filter by a specific host/host@vlan
--! @param vlan_id specify the host_ip filter vlan separately
--! @return table with stats on success, nil otherwise.
function interface.getActiveFlowsStats(string host_ip=nil, int vlan_id=nil)

--! @brief Get the interface maximum speed.
--! @param ifname the interface name.
--! @return the interface maximum speed on success, nil otherwise.
function interface.getMaxIfSpeed(string ifname)

--! @brief Reset interface packets counters.
--! @param only_drops if true, only reset the packet drops counter
function interface.resetCounters(bool only_drops=true)

--! @brief Reset all the hosts and L2 devices stats (e.g. traffic and application data).
--! @note this will also reset the stats of the inactive hosts.
function interface.resetStats()

--! @brief Get the name of the remote probe when connected via ZMQ.
--! @return endpoint name on success, nil otherwise.
function interface.getEndpoint()

--! @brief Check if the interface captures raw packets.
--! @return true if the interface is a packet interface, false otherwise.
--! @note ZMQ interfaces, for example, are not packet interfaces but flow interfaces.
function interface.isPacketInterface()

--! @brief Check if the network interface can be used to perform network discovery.
--! @return true if the interface is discoverable, false otherwise.
function interface.isDiscoverableInterface()

--! @brief Check if current interface is an nEdge bridge interface.
--! @return true if the interface is a bridge interface, false otherwise.
function interface.isBridgeInterface()

--! @brief Check if the network interface is a PcapInterface.
--! @return true if the interface is a PcapInterface, false otherwise.
function interface.isPcapDumpInterface()

--! @brief Check if the network interface is a ViewInterface.
--! @return true if the interface is a ViewInterface, false otherwise.
function interface.isView()

--! @brief Check if the network interface is viewed by a ViewInterface.
--! @return true if the interface is viewed by a ViewInterface, false otherwise.
function interface.isViewed()

--! @brief Get the interface ID of the ViewInterface above the current viewed interface.
--! @return the ViewInterface interface ID on success, nil otherwise.
function interface.viewedBy()

--! @brief Get the interface ID of the ViewInterface is a loopback interface.
--! @return true if the interface is a loopback, false otherwise.
function interface.isLoopback()

--! @brief Check if the network interface has started capturing packets.
--! @return true if the interface is running, false otherwise.
function interface.isRunning()

--! @brief Check if the network interface has been temporary paused.
--! @return true if the interface is paused, false otherwise.
function interface.isIdle()

--! @brief Temporary pause or unpause a network interface.
--! @param state if true, the interface will be paused, otherwise resumed.
function interface.setInterfaceIdleState(bool state)

--! @brief Get many information about the interface traffic and status.
--! @return table with interface stats (see NetworkInterface::lua) on success, nil otherwise.
function interface.getStats()

--! @brief Get local network stats.
--! @return table (network_name -> network_stats) on success (see NetworkStats::lua), nil otherwise.
function interface.getNetworksStats()

--! @brief Get a specific local network stats.
--! @param network_id the numeric ID of the network.
--! @return the network stats on success (see NetworkStats::lua), nil otherwise.
function interface.getNetworkStats(int network_id)

--! @brief Get active autonomous systems information.
--! @param pag_options options for the paginator.
--! @return table (numASes, ASes) on success (see AutonomousSystem::lua), nil otherwise.
function interface.getASesInfo(table pag_options=nil)

--! @brief Get information about a specifc Autonomous System.
--! @param asn the AS number.
--! @return AS information on success (see AutonomousSystem::lua), nil otherwise.
function interface.getASInfo(int asn)

--! @brief Get active countries information.
--! @param pag_options options for the paginator.
--! @return table (numCountries, Countries) on success (see Country::lua), nil otherwise.
function interface.getCountriesInfo(table pag_options=nil)

--! @brief Get active VLAN information.
--! @return table (numVLANs, VLANs) on success (see VLAN::lua), nil otherwise.
function interface.getVLANsList()

--! @brief Get a specific VLAN information.
--! @oaram vlan_id the VLAN id to query.
--! @return VLAN information on success (see VLAN::lua), nil otherwise.
function interface.getVLANInfo(int vlan_id)

--! @brief Get host pools information, like the number of members in the pool.
--! @return host pools information on success, nil otherwise.
function interface.getHostPoolsInfo()

--! @brief Reset the host pools traffic accounted in quotas (nEdge only).
function interface.resetPoolsQuotas()

--! @brief Returns a list of active sFlow devices.
--! @return table (device_ip -> device_ip_numeric) on success, nil otherwise.
function interface.getSFlowDevices()

--! @brief Returns information about a specific sFlow device interfaces.
--! @param device_ip the sFlow device IP.
--! @return table (if_idx -> if_information) on success, nil otherwise.
function interface.getSFlowDeviceInfo(string device_ip)

--! @brief Captures a 'duration' long pcap file. The capture is performed in background.
--! @param duration The pcap duration (in seconds)
--! @param bpf_filter An optional BPF filtering expression
--! @return The path of the pcap file, nil otherwise.
function interface.captureToPcap(int duration, string bpf_filter)

--! @brief Checks if there is a pending captureToPcap() in progress.
--! @return True is there is an ongoing capture, false otherwise.
function interface.isCaptureRunning()

--! @brief Stops a running capture.
function interface.stopRunningCapture()

--! @brief Get information about the active PODs (eBPF only).
--! @return a table with active PODs (see ContainerStats::lua).
function interface.getPodsStats()

--! @brief Get information about the active Containers (eBPF only).
--! @param pod_filter a filter to only show containers for the given POD
--! @return a table with active containers (see ContainerStats::lua).
function interface.getContainersStats(string pod_filter = nil)
