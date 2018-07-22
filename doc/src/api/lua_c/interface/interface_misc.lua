--! @brief Set the *active interface* by using the interface id.
--! @param id the interface id.
--! @return the interface name on success, nil otherwise.
function interface.setActiveInterfaceId(int id)

--! @brief Get the available ntopng network interfaces.
--! @return a table containing (ifid -> ifname) mappings.
function interface.getIfNames()

--! @brief Set the *active interface* by using the interface name.
--! @param ifname the interface name.
function interface.select(string ifname)

--! @brief Get the interface maximum speed.
--! @param ifname the interface name.
--! @return the interface maximum speed on success, nil otherwise.
function interface.getMaxIfSpeed(string ifname)

--! @brief Reset interface packet counters.
--! @param only_drops if true, only reset the packet drops counter
function interface.resetCounters(bool only_drops=true)

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

--! @brief Check if the network interface is a PcapInterface.
--! @return true if the interface is a PcapInterface, false otherwise.
function interface.isPcapDumpInterface()

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
--! @return table with interface stats success, nil otherwise.
function interface.getStats()

--! @brief Get local network stats.
--! @return table (network_name -> network_stats) on success, nil otherwise.
function interface.getNetworksStats()

--! @brief Get active autonomous systems information.
--! @param pag_options options for the paginator.
--! @return table (numASes, ASes) on success, nil otherwise.
function interface.getASesInfo(table pag_options=nil)

--! @brief Get information about a specifc Autonomous System.
--! @param asn the AS number.
--! @return AS information on success, nil otherwise.
function interface.getASInfo(int asn)

--! @brief Get active countries information.
--! @param pag_options options for the paginator.
--! @return table (numCountries, Countries) on success, nil otherwise.
function interface.getCountriesInfo(table pag_options=nil)

--! @brief Get active VLAN information.
--! @return table (numVLANs, VLANs) on success, nil otherwise.
function interface.getVLANsList()

--! @brief Get a specific VLAN information.
--! @oaram vlan_id the VLAN id to query.
--! @return VLAN information on success, nil otherwise.
function interface.getVLANInfo(int vlan_id)

--! @brief Reload Host Pool membership information after changes from Lua.
function interface.reloadHostPools()

--! @brief Get host pools information, like the number of members in the pool.
--! @return host pools information on success, nil otherwise.
function interface.getHostPoolsInfo()

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
