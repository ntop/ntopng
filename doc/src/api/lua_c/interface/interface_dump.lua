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
