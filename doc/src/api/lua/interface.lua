---------------------------------
--! @file
--! @brief The 'interface' object API.
---------------------------------

--! @brief Set the *active interface* by using the interface id.
--! @param id the interface id.
--! @return the interface name on success, nil otherwise.
function setActiveInterfaceId(int id)

--! @brief Get the available ntopng network interfaces.
--! @return a table containing (ifid -> ifname) mappings.
function getIfNames()

--! @brief Set the *active interface* by using the interface name.
--! @param ifname the interface name.
function select(string ifname)

--! @brief Get the interface maximum speed.
--! @param ifname the interface name.
--! @return the interface maximum speed on success, nil otherwise.
function getMaxIfSpeed(string ifname)

--! @brief Get many information about the interface traffic and status.
--! @return table with interface stats success, nil otherwise.
function getStats()

--! @brief Reset interface packet counters.
--! @param only_drops if true, only reset the packet drops counter
function resetCounters(bool only_drops=true)

--! @brief Get nDPI protocol information of the network interface/a specific host.
--! @param host_ip filter by a specific host/host@vlan
--! @param vlan_id specify the host_ip filter vlan separately
--! @return table with nDPI stats on success, nil otherwise.
function getnDPIStats(string host_ip=nil, int vlan_id=nil)

--! @brief Convert a nDPI protocol id to a protocol name
--! @param proto the protocol id to convert
--! @return the protocol name on success, nil otherwise.
function getnDPIProtoName(int proto)

--! @brief Convert a protocol name to the corresponding nDPI protocol id
--! @param proto the protocol name to convert
--! @return the protocol id on success, nil otherwise.
function getnDPIProtoId(string proto)

--! @brief Convert a category name to the corresponding nDPI category id
--! @param category the category name to convert
--! @return the category id on success, nil otherwise.
function getnDPICategoryId(string category)

--! @brief Convert a nDPI category id to a category name
--! @param category the category id to convert
--! @return the category name on success, nil otherwise.
function getnDPICategoryName(int category)

--! @brief Get the nDPI category currently associated to the protocol
--! @param proto the protocol id to query the category for
--! @return a table (id->category_id, name->category_name) on success, nil otherwise.
--! @note the protocol to category mapping can be changed dynamically via *setnDPICategory*
function getnDPIProtoCategory(int proto)

--! @brief Associate the protocol to the specified nDPI category
--! @param proto the protocol id
--! @param category the category id
function setnDPIProtoCategory(int proto, int category)

--! @brief Get the number of active flows by nDPI protocol
--! @return a table (protocol_name -> num_flows) on success, nil otherwise.
function getnDPIFlowsCount()

--! @brief Get active flows status statistics
--! @return a table (status -> num_flows) for every status (RST, SYN, Established, FIN) on success, nil otherwise.
function getFlowsStatus()

--! @brief Get the available nDPI protocols
--! @param category_filter only show protocols of this category
--! @param skip_critical if true, skip protocols marked as critical for a network (e.g. DNS)
--! @return a table (proto_name -> proto_id) on success, nil otherwise.
function getnDPIProtocols(int category_filter=nil, bool skip_critical=false)

--! @brief Get the available nDPI categories
--! @return a table (category_name -> category_id) on success, nil otherwise.
function getnDPICategories()

--! @brief Get active hosts information.
--! @param show_details enable extended information.
--! @param sortColumn column to use for sorting.
--! @param maxHits maximum number of returned items.
--! @param toSkip number of initial items to skip after sorting.
--! @param a2zSortOrder if true, enable ascending sort order, otherwise order is descending.
--! @param country filter hosts by country code.
--! @param os_filter filter hosts by os code.
--! @param vlan_filter filter hosts by vlan ID.
--! @param asn_filter filter hosts by ASN filter.
--! @param network_filter filter hosts by local network id.
--! @param mac_filter filter hosts by MAC address.
--! @param pool_filter filter hosts by host pool ID.
--! @param ipver_filter filter hosts by IP version, must be 4 or 6.
--! @param proto_filter filter hosts by nDPI protocol ID.
--! @param filtered_hosts if true, only return hosts with blocked flows.
--! @param blacklisted_hosts if true, only return blacklisted hosts.
--! @param hide_top_hidden if true, avoid returning hosts marked as "top hidden".
--! @return a table (numHosts, nextSlot, hosts) where hosts is a table (hostkey -> hostinfo) on success, nil on error.
--! @note it's better to use the more efficient helper `callback_utils.foreachHost` for generic hosts iteration.
function getHostsInfo(bool show_details=true, string sortColumn="column_ip", int maxHits=32768, int toSkip=0, bool a2zSortOrder=true, string country=nil, string os_filter=nil, int vlan_filter=nil, int asn_filter=nil, int network_filter=nil, string mac_filter=nil, int pool_filter=nil, int ipver_filter=nil, int proto_filter=nil, bool filtered_hosts=false, bool blacklisted_hosts=false, bool hide_top_hidden=false)

--! @brief Get active local hosts information. See `getHostsInfo` for parameters description.
--! @note it's better to use the more efficient helper `callback_utils.foreachLocalHost` for generic hosts iteration.
function getLocalHostsInfo(...)

--! @brief Get active remote hosts information. See `getHostsInfo` for parameters description.
function getRemoteHostsInfo(...)

--! @brief Get host information.
--! @param host_ip host/host@vlan.
--! @param vlan_id specify the host_ip vlan separately.
--! @return table with host information on success, nil otherwise.
function getHostInfo(string host_ip, int vlan_id=nil)

--! @brief Get host country.
--! @param host_ip host/host@vlan.
--! @return the host country code on success, nil otherwise
function getHostCountry(string host_ip)

--! @brief Group active hosts by a specific criteria.
--! @param show_details enable extended information.
--! @param groupBy the group criteria.
--! @param country filter hosts by country code.
--! @param os_filter filter hosts by os code.
--! @param vlan_filter filter hosts by vlan ID.
--! @param asn_filter filter hosts by ASN filter.
--! @param network_filter filter hosts by local network id.
--! @param pool_filter filter hosts by host pool ID.
--! @param ipver_filter filter hosts by IP version, must be 4 or 6.
--! @return table with grouped host information on success, nil otherwise.
function getGroupedHosts(bool show_details=true, string groupBy="column_ip", string country=nil, string os_filter=nil, int vlan_filter=nil, int asn_filter=nil, int network_filter=nil, int pool_filter=nil, int ipver_filter=nil)

--! @brief Get local network stats.
--! @return table (network_name -> network_stats) on success, nil otherwise.
function getNetworksStats()

--! @brief Get active flows information.
--! @param host_ip filter by host/host@vlan.
--! @param pag_options options for the paginator.
--! @return table (num_flows, flows) on success, nil otherwise.
function getFlowsInfo(string host_ip=nil, table pag_options=nil)

--! @brief Group active flows by a specified criteria.
--! @param group_col the grouping column
--! @param pag_options options for the paginator.
--! @return table with grouped flows information on success, nil otherwise.
function getGroupedFlows(string group_col, table pag_options=nil)

--! @brief Get active flows nDPI bytes count.
--! @return table (num_flows, protos, breeds) which map (protocol_name->bytes_count) on success, nil otherwise.
function getFlowsStats()

--! @brief Computes the unique flow identifier.
--! @param cli_ip host/host@vlan.
--! @param cli_vlan specify the cli_ip vlan separately.
--! @param srv_ip host/host@vlan.
--! @param srv_vlan specify the srv_ip vlan separately.
--! @param l4_proto l4 protocol id
--! @return the numeric flow key on success, nil otherwise.
function getFlowKey(string cli_ip, int cli_vlan, string srv_ip, int srv_vlan, int l4_proto)

--! @brief Returns a single active flow information.
--! @param key the flow key.
--! @return the flow information on success, nil otherwise.
function findFlowByKey(int key)

--! @brief Drops an active flow traffic.
--! @param key the flow key.
--! @note this is only effective when running in inline mode.
function dropFlowTraffic(int key)

--! @brief Enable or disable an active flow traffic dump to disk.
--! @param key the flow key.
--! @param enable or disable the dump.
function dumpFlowTraffic(int key, int enable)

--! @brief Search hosts by name, ip or other information.
--! @param query the string to use.
--! @return the found hosts information on success, nil otherwise.
function findHost(string query)

--! @brief Search hosts by MAC address.
--! @param mac the mac address filter.
--! @return the found hosts information on success, nil otherwise.
function findHostByMac(string mac)

--! @brief Change the host dump policy.
--! @param dump_enabled if enable, host traffic will be dumped to disk.
--! @param host_ip filter by a specific host/host@vlan
--! @param vlan_id specify the host_ip filter vlan separately
function setHostDumpPolicy(bool dump_enabled, string host_ip, int vlan_id=nil)

--! @brief Check if the interface traffic dump is enabled.
--! @return the current interface dump policy on success, nil otherwise.
function getInterfaceDumpDiskPolicy()

--! @brief Check if the interface traffic dump to TAP interface is enabled.
--! @return the current interface TAP dump policy on success, nil otherwise.
function getInterfaceDumpTapPolicy()

--! @brief Get the TAP interface name used for TAP dump.
--! @return the configured TAP interface name on success, nil otherwise.
function getInterfaceDumpTapName()

--! @brief Retrieve the maximum number of packets which can be dumped to a single file.
--! @return max packets per dump file on success, nil otherwise.
function getInterfaceDumpMaxPkts()

--! @brief Retrieve the maximum duration in seconds for single dump file.
--! @return max duration per dump file on success, nil otherwise.
function getInterfaceDumpMaxSec()

--! @brief Retrieve the maximum number of dump files which can be created.
--! @return max number of dump file on success, nil otherwise.
function getInterfaceDumpMaxFiles()

--! @brief Retrieve the current number of packets dumped to disk.
--! @return number of dumped packets on success, nil otherwise.
function getInterfacePacketsDumpedFile()

--! @brief Retrieve the current number of packets dumped to TAP.
--! @return number of dumped packets on success, nil otherwise.
function getInterfacePacketsDumpedTap()

--! @brief Get the name of the remote probe when connected via ZMQ.
--! @return endpoint name on success, nil otherwise.
function getEndpoint()

--! @brief Check if the interface captures raw packets.
--! @return true if the interface is a packet interface, false otherwise.
--! @note ZMQ interfaces, for example, are not packet interfaces but flow interfaces.
function isPacketInterface()

--! @brief Check if the network interface can be used to perform network discovery.
--! @return true if the interface is discoverable, false otherwise.
function isDiscoverableInterface()

--! @brief Check if the network interface is a PcapInterface.
--! @return true if the interface is a PcapInterface, false otherwise.
function isPcapDumpInterface()

--! @brief Check if the network interface has started capturing packets.
--! @return true if the interface is running, false otherwise.
function isRunning()

--! @brief Check if the network interface has been temporary paused.
--! @return true if the interface is paused, false otherwise.
function isIdle()

--! @brief Temporary pause or unpause a network interface.
--! @param state if true, the interface will be paused, otherwise resumed.
function setInterfaceIdleState(bool state)

--! @brief Retrieve active L2 devices information.
--! @param sortColumn column to use for sorting.
--! @param maxHits maximum number of returned items.
--! @param toSkip number of initial items to skip after sorting.
--! @param a2zSortOrder if true, enable ascending sort order, otherwise order is descending.
--! @param sourceMacsOnly if true, only sender devices will be returned.
--! @param manufacturer filter by device manufacturer.
--! @param pool_filter filter by host pool ID.
--! @param devtype_filter filter by device type.
--! @param location_filter filter by device location, "lan" or "wan".
--! @param dhcpMacsOnly if true, only devices which made DHCP requests will be returned.
--! @return a table (numMacs, nextSlot, macs) on success, nil otherwise.
--! @note it's better to use the more efficient helper `callback_utils.getDevicesIterator` for generic devices iteration.
function getMacsInfo(string sortColumn="column_mac", int maxHits=32768, int toSkip=0, bool a2zSortOrder=true, sourceMacsOnly=false, string manufacturer=nil, int pool_filter=nil, int devtype_filter=nil, string location_filter=nil, bool dhcpMacsOnly=false)

--! @brief Retrieve information about a specific L2 device.
--! @param mac the mac to query information for.
--! @return device information on success, nil otherwise.
function getMacInfo(string mac)

--! @brief Get a list of MAC manufacturers from active devices.
--! @param maxHits maximum number of returned items.
--! @param sourceMacsOnly if true, only sender devices will be returned.
--! @param devtype_filter filter by device type.
--! @param location_filter filter by device location, "lan" or "wan".
--! @param dhcpMacsOnly if true, only consider devices which made DHCP requests.
--! @return table (manufacturer -> num_active_devices) on success, nil otherwise.
function getMacManufacturers(int maxHits=32768, bool sourceMacsOnly=false, int devtype_filter=nil, string location_filter=nil, bool dhcpMacsOnly=false)

--! @brief Set L2 device operating system.
--! @param mac device MAC address
--! @param os_id the operating system id to set.
function setMacOperatingSystem(string mac, int os_id)

--! @brief Set L2 device type.
--! @param mac device MAC address
--! @param device_type the device type id to set.
--! @param overwrite if true, the existing device type, if any, will be overwritten.
function setMacDeviceType(string mac, int device_type, bool overwrite)

--! @brief Get a list of device types from active devices.
--! @param maxHits maximum number of returned items.
--! @param sourceMacsOnly if true, only sender devices will be return
--! @param manufacturer filter by device manufacturer.ed.
--! @param location_filter filter by device location, "lan" or "wan".
--! @param dhcpMacsOnly if true, only devices which made DHCP requests will be returned.
--! @return table (device_type -> num_active_devices) on success, nil otherwise.
function getMacDeviceTypes(int max_hits=32768, bool sourceMacsOnly=false, string manufacturer=nil, string location_filter=nil, bool dhcpMacsOnly=false)

--! @brief Get active autonomous systems information.
--! @param pag_options options for the paginator.
--! @return table (numASes, ASes) on success, nil otherwise.
function getASesInfo(table pag_options=nil)

--! @brief Get information about a specifc Autonomous System.
--! @param asn the AS number.
--! @return AS information on success, nil otherwise.
function getASInfo(int asn)

--! @brief Get active countries information.
--! @param pag_options options for the paginator.
--! @return table (numCountries, Countries) on success, nil otherwise.
function getCountriesInfo(table pag_options=nil)

--! @brief Get active VLAN information.
--! @return table (numVLANs, VLANs) on success, nil otherwise.
function getVLANsList()

--! @brief Get a specific VLAN information.
--! @oaram vlan_id the VLAN id to query.
--! @return VLAN information on success, nil otherwise.
function getVLANInfo(int vlan_id)

--! @brief Reload Host Pool membership information after changes from Lua.
function reloadHostPools()

--! @brief Get the pool of the specified L2 device. This also works for inactive devices.
--! @oaram mac L2 device MAC address.
--! @return the device pool id on success, nil otherwise.
--! @note nil is also returned for devices which do not belong to any pool.
function findMacPool(string mac)

--! @brief Get host pools information, like the number of members in the pool.
--! @return host pools information on success, nil otherwise.
function getHostPoolsInfo()

--! @brief Returns a list of active sFlow devices.
--! @return table (device_ip -> device_ip_numeric) on success, nil otherwise.
function getSFlowDevices()

--! @brief Returns information about a specific sFlow device interfaces.
--! @param device_ip the sFlow device IP.
--! @return table (if_idx -> if_information) on success, nil otherwise.
function getSFlowDeviceInfo(string device_ip)
