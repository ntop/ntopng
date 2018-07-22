--! @brief Get active flows information.
--! @param host_ip filter by host/host@vlan.
--! @param pag_options options for the paginator.
--! @return table (num_flows, flows) on success, nil otherwise.
function interface.getFlowsInfo(string host_ip=nil, table pag_options=nil)

--! @brief Get active flows status statistics
--! @return a table (status -> num_flows) for every status (RST, SYN, Established, FIN) on success, nil otherwise.
function interface.getFlowsStatus()


--! @brief Group active flows by a specified criteria.
--! @param group_col the grouping column
--! @param pag_options options for the paginator.
--! @return table with grouped flows information on success, nil otherwise.
function interface.getGroupedFlows(string group_col, table pag_options=nil)

--! @brief Get active flows nDPI bytes count.
--! @return table (num_flows, protos, breeds) which map (protocol_name->bytes_count) on success, nil otherwise.
function interface.getFlowsStats()

--! @brief Get the number of active flows by nDPI protocol
--! @return a table (protocol_name -> num_flows) on success, nil otherwise.
function interface.getnDPIFlowsCount()

--! @brief Computes the unique flow identifier.
--! @param cli_ip host/host@vlan.
--! @param cli_vlan specify the cli_ip vlan separately.
--! @param srv_ip host/host@vlan.
--! @param srv_vlan specify the srv_ip vlan separately.
--! @param l4_proto l4 protocol id
--! @return the numeric flow key on success, nil otherwise.
function interface.getFlowKey(string cli_ip, int cli_vlan, string srv_ip, int srv_vlan, int l4_proto)

--! @brief Returns a single active flow information.
--! @param key the flow key.
--! @return the flow information on success, nil otherwise.
function interface.findFlowByKey(int key)

--! @brief Drops an active flow traffic.
--! @param key the flow key.
--! @note this is only effective when running in inline mode.
function interface.dropFlowTraffic(int key)

--! @brief Enable or disable an active flow traffic dump to disk.
--! @param key the flow key.
--! @param enable or disable the dump.
function interface.dumpFlowTraffic(int key, int enable)
