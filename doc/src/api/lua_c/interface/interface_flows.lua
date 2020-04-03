--! @brief Get active flows information.
--! @param host_ip filter by host/host@vlan.
--! @param pag_options options for the paginator.
--! @return table (num_flows, flows) on success (see Flow::lua), nil otherwise.
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
--! @param cli_port the client port.
--! @param srv_ip host/host@vlan.
--! @param srv_port the server port.
--! @param l4_proto l4 protocol id
--! @return the numeric flow key on success, nil otherwise.
function interface.getFlowKey(string cli_ip, int cli_port, string srv_ip, int srv_port, int l4_proto)

--! @brief Get flow information by specifying the 5-tuple.
--! @param cli_ip host.
--! @param srv_ip host.
--! @param vlan the VLAN.
--! @param cli_port the client port.
--! @param srv_port the server port.
--! @param l4_proto l4 protocol id
--! @return a table with the flow information (see Flow::lua) on success, nil otherwise.
function interface.findFlowByTuple(string cli_ip, string srv_ip, int vlan, int cli_port, int srv_port, int l4_proto)

--! @brief Returns a single active flow information.
--! @param key the flow key.
--! @param hashid the flow hash ID.
--! @return the flow information on success, nil otherwise.
function interface.findFlowByKeyAndHashId(int key, int hashid)

--! @brief Drops an active flow traffic.
--! @param key the flow key.
--! @param hashid the flow hash ID.
--! @note this is only effective when using nEdge.
--! @return true on success, false otherwise
function interface.dropFlowTraffic(int key, int hashid)

