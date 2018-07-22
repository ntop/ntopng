--! @brief Get nDPI protocol information of the network interface/a specific host.
--! @param host_ip filter by a specific host/host@vlan
--! @param vlan_id specify the host_ip filter vlan separately
--! @return table with nDPI stats on success, nil otherwise.
function interface.getnDPIStats(string host_ip=nil, int vlan_id=nil)

--! @brief Convert a nDPI protocol id to a protocol name
--! @param proto the protocol id to convert
--! @return the protocol name on success, nil otherwise.
function interface.getnDPIProtoName(int proto)

--! @brief Convert a protocol name to the corresponding nDPI protocol id
--! @param proto the protocol name to convert
--! @return the protocol id on success, nil otherwise.
function interface.getnDPIProtoId(string proto)

--! @brief Convert a category name to the corresponding nDPI category id
--! @param category the category name to convert
--! @return the category id on success, nil otherwise.
function interface.getnDPICategoryId(string category)

--! @brief Convert a nDPI category id to a category name
--! @param category the category id to convert
--! @return the category name on success, nil otherwise.
function interface.getnDPICategoryName(int category)

--! @brief Get the nDPI category currently associated to the protocol
--! @param proto the protocol id to query the category for
--! @return a table (id->category_id, name->category_name) on success, nil otherwise.
--! @note the protocol to category mapping can be changed dynamically via *setnDPICategory*
function interface.getnDPIProtoCategory(int proto)

--! @brief Associate the protocol to the specified nDPI category
--! @param proto the protocol id
--! @param category the category id
function interface.setnDPIProtoCategory(int proto, int category)

--! @brief Get the available nDPI protocols
--! @param category_filter only show protocols of this category
--! @param skip_critical if true, skip protocols marked as critical for a network (e.g. DNS)
--! @return a table (proto_name -> proto_id) on success, nil otherwise.
function interface.getnDPIProtocols(int category_filter=nil, bool skip_critical=false)

--! @brief Get the available nDPI categories
--! @return a table (category_name -> category_id) on success, nil otherwise.
function interface.getnDPICategories()
