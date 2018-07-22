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
function interface.getMacsInfo(string sortColumn="column_mac", int maxHits=32768, int toSkip=0, bool a2zSortOrder=true, sourceMacsOnly=false, string manufacturer=nil, int pool_filter=nil, int devtype_filter=nil, string location_filter=nil, bool dhcpMacsOnly=false)

--! @brief Retrieve information about a specific L2 device.
--! @param mac the mac to query information for.
--! @return device information on success, nil otherwise.
function interface.getMacInfo(string mac)

--! @brief Get a list of MAC manufacturers from active devices.
--! @param maxHits maximum number of returned items.
--! @param sourceMacsOnly if true, only sender devices will be returned.
--! @param devtype_filter filter by device type.
--! @param location_filter filter by device location, "lan" or "wan".
--! @param dhcpMacsOnly if true, only consider devices which made DHCP requests.
--! @return table (manufacturer -> num_active_devices) on success, nil otherwise.
function interface.getMacManufacturers(int maxHits=32768, bool sourceMacsOnly=false, int devtype_filter=nil, string location_filter=nil, bool dhcpMacsOnly=false)

--! @brief Set L2 device operating system.
--! @param mac device MAC address
--! @param os_id the operating system id to set.
function interface.setMacOperatingSystem(string mac, int os_id)

--! @brief Set L2 device type.
--! @param mac device MAC address
--! @param device_type the device type id to set.
--! @param overwrite if true, the existing device type, if any, will be overwritten.
function interface.setMacDeviceType(string mac, int device_type, bool overwrite)

--! @brief Get a list of device types from active devices.
--! @param maxHits maximum number of returned items.
--! @param sourceMacsOnly if true, only sender devices will be return
--! @param manufacturer filter by device manufacturer.ed.
--! @param location_filter filter by device location, "lan" or "wan".
--! @param dhcpMacsOnly if true, only devices which made DHCP requests will be returned.
--! @return table (device_type -> num_active_devices) on success, nil otherwise.
function interface.getMacDeviceTypes(int max_hits=32768, bool sourceMacsOnly=false, string manufacturer=nil, string location_filter=nil, bool dhcpMacsOnly=false)

--! @brief Get the pool of the specified L2 device. This also works for inactive devices.
--! @oaram mac L2 device MAC address.
--! @return the device pool id on success, nil otherwise.
--! @note nil is also returned for devices which do not belong to any pool.
function interface.findMacPool(string mac)
