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

--! @brief Get the nDPI protocol breed associated to the protocol
--! @param proto the protocol id to query
--! @return the protocol breed string on success, nil otherwise.
function interface.getnDPIProtoBreed(int proto, int category)

--! @brief Get the available nDPI protocols
--! @param category_filter only show protocols of this category
--! @param skip_critical if true, skip protocols marked as critical for a network (e.g. DNS)
--! @return a table (proto_name -> proto_id) on success, nil otherwise.
function interface.getnDPIProtocols(int category_filter=nil, bool skip_critical=false)

--! @brief Get the available nDPI categories
--! @return a table (category_name -> category_id) on success, nil otherwise.
function interface.getnDPICategories()
