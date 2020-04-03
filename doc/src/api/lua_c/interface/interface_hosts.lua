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
--! @param traffic_type_filter used to filter one/bidirectional flows
--! @param filtered_hosts if true, only return hosts with blocked flows.
--! @param blacklisted_hosts if true, only return blacklisted hosts.
--! @param hide_top_hidden if true, avoid returning hosts marked as "top hidden".
--! @param anomalousOnly if true, only return hosts with anomalies (beta feature).
--! @param dhcpOnly if true, only return hosts for which DHCP traffic was seen.
--! @param cidr_filter filter the hosts to return by using a network CIDR.
--! @return a table (numHosts, nextSlot, hosts) where hosts is a table (hostkey -> hostinfo) on success, nil on error.
--! @note it's better to use the more efficient helper `callback_utils.foreachHost` for generic hosts iteration.
function interface.getHostsInfo(bool show_details=true, string sortColumn="column_ip", int maxHits=32768, int toSkip=0, bool a2zSortOrder=true, string country=nil, string os_filter=nil, int vlan_filter=nil, int asn_filter=nil, int network_filter=nil, string mac_filter=nil, int pool_filter=nil, int ipver_filter=nil, int proto_filter=nil, int traffic_type_filter=nil, bool filtered_hosts=false, bool blacklisted_hosts=false, bool hide_top_hidden=false, bool anomalousOnly=false, bool dhcpOnly=false, string cidr_filter=nil)

--! @brief Get active local hosts information. See `getHostsInfo` for parameters description.
--! @note it's better to use the more efficient helper `callback_utils.foreachLocalHost` for generic hosts iteration.
function interface.getLocalHostsInfo(...)

--! @brief Get active remote hosts information. See `getHostsInfo` for parameters description.
function interface.getRemoteHostsInfo(...)

--! @brief Get active hosts information for hosts which are in the broadcast domain. See `getHostsInfo` for parameters description.
function interface.getBroadcastDomainHostsInfo(...)

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
function interface.getGroupedHosts(bool show_details=true, string groupBy="column_ip", string country=nil, string os_filter=nil, int vlan_filter=nil, int asn_filter=nil, int network_filter=nil, int pool_filter=nil, int ipver_filter=nil)

--! @brief Get host information.
--! @param host_ip host/host@vlan.
--! @param vlan_id specify the host_ip vlan separately.
--! @return table with host information on success, nil otherwise.
function interface.getHostInfo(string host_ip, int vlan_id=nil)

--! @brief Get host country.
--! @param host_ip host/host@vlan.
--! @return the host country code on success, nil otherwise.
function interface.getHostCountry(string host_ip)

--! @brief Search hosts by name, ip or other information.
--! @param query the string to use.
--! @return the found hosts information on success, nil otherwise.
function interface.findHost(string query)

--! @brief Search hosts by MAC address.
--! @param mac the mac address filter.
--! @return the found hosts information on success, nil otherwise.
function interface.findHostByMac(string mac)

--! @brief Reset the stats (e.g. traffic and application data) for the given host.
--! @param host_ip host/host@vlan.
--! @return true if the reset request was successful, false otherwise.
--! @note The host must be active in order to reset it. See also interface.resetStats
function interface.resetHostStats(string host_ip)

--! @brief Delete all the data stored for the given host.
--! @param host_ip host/host@vlan.
--! @return true if the delete request was successful, false otherwise.
function interface.deleteHostData(string host_ip)

--! @brief Set the operating system ID of an host
--! @param host_ip host/host@vlan.
--! @param os_id the operating system ID.
function interface.setHostOperatingSystem(string host_ip, int os_id)

--! @brief Get the number of active local hosts.
--! @return the local hosts number.
function interface.getNumLocalHosts()

--! @brief Lists all the detected HTTP hosts
--! @return a table containing the HTTP hosts information (see HTTPstats::luaVirtualHosts)
function interface.listHTTPhosts()

--! @brief Try to resolve an host name via MDNS.
--! @param host_ip the host to resolve
--! @return the resolved host name on success, an empty otherwise.
function interface.mdnsResolveName(string host_ip)
