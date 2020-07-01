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
--! @return a table (numMacs, nextSlot, macs) on success, nil otherwise.
--! @note it's better to use the more efficient helper `callback_utils.getDevicesIterator` for generic devices iteration.
function interface.getMacsInfo(string sortColumn="column_mac", int maxHits=32768, int toSkip=0, bool a2zSortOrder=true, bool sourceMacsOnly=false, string manufacturer=nil, int pool_filter=nil, int devtype_filter=nil, string location_filter=nil)

--! @brief Retrieve information about a specific L2 device.
--! @param mac the mac to query information for.
--! @return device information on success, nil otherwise.
function interface.getMacInfo(string mac)

--! @brief Get the L2 hosts which have the specified MAC address.
--! @param mac the mac.
--! @return a table containing the matching hosts.
function interface.getMacHosts(string mac)

--! @brief Get a list of MAC manufacturers from active devices.
--! @param maxHits maximum number of returned items.
--! @param sourceMacsOnly if true, only sender devices will be returned.
--! @param devtype_filter filter by device type.
--! @param location_filter filter by device location, "lan" or "wan".
--! @return table (manufacturer -> num_active_devices) on success, nil otherwise.
function interface.getMacManufacturers(int maxHits=32768, bool sourceMacsOnly=false, int devtype_filter=nil, string location_filter=nil)

--! @brief Set L2 device operating system.
--! @param mac device MAC address
--! @param os_id the operating system id to set.
function interface.setMacOperatingSystem(string mac, int os_id)

--! @brief Get a list of device types from active devices.
--! @param maxHits maximum number of returned items.
--! @param sourceMacsOnly if true, only sender devices will be return
--! @param manufacturer filter by device manufacturer.ed.
--! @param location_filter filter by device location, "lan" or "wan".
--! @return table (device_type -> num_active_devices) on success, nil otherwise.
function interface.getMacDeviceTypes(int maxHits=32768, bool sourceMacsOnly=false, string manufacturer=nil, string location_filter=nil)

--! @brief Get the pool of the specified L2 device. This also works for inactive devices.
--! @oaram mac L2 device MAC address.
--! @return the device pool id on success, nil otherwise.
--! @note nil is also returned for devices which do not belong to any pool.
function interface.findMacPool(string mac)

--! @brief Reset the stats (e.g. traffic and application data) for the given device.
--! @oaram mac L2 device MAC address.
--! @return true if the reset request was successful, false otherwise.
--! @note The device must be active in order to reset it. See also interface.resetStats
function interface.resetMacStats(string mac)

--! @brief Delete all the data stored for the given host.
--! @oaram mac L2 device MAC address.
--! @return true if the delete request was successful, false otherwise.
function interface.deleteMacData(string mac)
