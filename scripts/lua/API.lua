-- API.lua

---------------------------------
--! @defgroup Script
--! @brief The lua scripts
--! @ingroup Lua
---------------------------------

-- -------------------------------
-- ! @file
-- ! @brief a Manual of API Lua.
-- ! @ingroup Script
-- -------------------------------

---------------------------------
--! @class ntop
--! @brief ntop lua class.
--! @ingroup Script
---------------------------------

---------------------------------
--! @class interface
--!  @brief network interface lua class.
--!  @ingroup Script
---------------------------------


--! @memberof interface
--! @brief Get the default network interface name.
--! @details For more information please read the @ref ntop_get_default_interface_name documentation.
--! @return {string} The default network interface name of ntopng.
function getDefaultIfName()


--! @memberof interface
--! @brief Sets the network interface name identified by Id as active one on which to perform operations.
--! @details For more information please read the @ref ntop_set_active_interface_id documentation.
--! @tparam number id param.
--! @return The network interface name of network interface identified by Id, nill otherwise.
function setActiveInterfaceId(id)

--! @memberof interface
--! @brief Get the network interface names.
--! @details For more information please read the @ref ntop_get_interface_names documentation.
--! @return A table with the id of the network interface as key and the network interface name as value.
function getIfNames ()

--! @memberof interface
--! @brief Find the network interface and set update the ntop_interface global variable.
--! @details For more information please read the @ref ntop_find_interface documentation.
--! @tparam string ifname The network interface name.
--! @return Update the ntop_interface global variable with the new network interface identified by ifname, nill if the network interface not exists.
function find(ifname)


--! @memberof interface
--! @brief Flush the host contacts of the network interface.
--! @details For more information please read the @ref ntop_flush_host_contacts documentation.
function flushHostContacts ()

--! @memberof interface
--! @brief Get the statistics of network interface.
--! @details For more information please read the @ref NetworkInterface::lua documentation.
--! @return An hashtable that contain the statistics of the network interface as {name, type, stats_packets, stats_bytes, stats_flows, stats_hosts, stats_drops, ethstats, ndpistats, pktstats}.
function getStats ()

--! @memberof interface
--! @brief Get the ndpi protocol name of protocol id of network interface.
--! @details For more information please read the @ref ntop_get_ndpi_protocol_name documentation.
--! @tparam number proto The protocol Id.
--! @return "Host-to-Host Contact" if protocol id is equal to host family id, the protocol name if network interface is not null and null otherwise.
function getNdpiProtoName (proto)

--! @memberof interface
--! @brief Get the hosts information of network interface.
--! @details For more information please read the @ref ntop_get_interface_hosts documentation.
--! @return An hashtable that contain the hosts information of the network interface.
function getHosts ()

--! @memberof interface
--! @brief Get details hosts information of network interface.
--! @details For more information please read the @ref ntop_get_interface_hosts_info documentation.
--! @tparam bool show_details Boolean variable that define the details level. Optional, for default it is set to true.
--! @return An hashtable that contain the hosts information of the network interface.
function getHostsInfo (show_details)

--! @memberof interface
--! @brief Get the aggregated hosts information of network interface.
--! @details For more information please read the @ref NetworkInterface::getActiveAggregatedHostsList documentation.
--! @tparam string family The family Id.
--! @tparam string host_name The host name.
--! @return An hashtable of hashtables containing the aggregated host information.
function getAggregatedHostsInfo(family,host_name)

--! @memberof interface
--! @brief Get the aggregation family of network interface.
--! @details Find the aggregation family for the network interface and get the name of the protocol. For more information please read the @ref NetworkInterface::getAggregatedFamilies documentation.
--! @return An hashtable containing the aggregation family protocol name.
function getAggregationFamilies()

--! @memberof interface
--! @brief Get the number of aggregated hosts of network interface.
--! @details Find the aggregation family for the network interface and get the name of the protocol. For more information please read the @ref ntop_get_interface_num_aggregated_hosts documentation.
--! @return Number of aggregated host.
function getNumAggregatedHosts()

--! @memberof interface
--! @brief Get the host information of network interface.
--! @details For more information please read the @ref ntop_get_interface_host_info documentation.
--! @tparam string host_ip The IP address of host.
--! @tparam number vlan_id Optional, the vlan Id.
--! @return The activity map in json format.
function getHostInfo(host_ip,vlan_id)

--! @memberof interface
--! @brief Get the activity map of host of network interface.
--! @details Find the aggregation family for the network interface and get the name of the protocol. For more information please read the @ref ntop_get_interface_host_activitymap documentation.
--! @tparam string host_ip The IP address of host.
--! @tparam bool aggregated Boolean value set to true if you want the activity map of aggregated host, false otherwise.
--! @tparam number vlan_id Optional, the vlan Id.
--! @return The activity map in json format.
function getHostActivityMap(host_ip,aggregated,vlan_id)

--! @memberof interface
--! @brief Restore the host of network interface.
--! @details Get the ntop interface global variable of lua and the IP address of host form the lua stack and restore the host into hash host of network interface.For more information please read the @ref ntop_restore_interface_host documentation.
--! @tparam string host_ip The IP address of host.
function restoreHost(host_ip)

--! @memberof interface
--! @brief Get the aggregated host information of network interface.
--! @details For more information please read the @ref ntop_get_interface_aggregated_host_info documentation.
--! @tparam string host_name The host name.
--! @return An hashtable of hashtables containing the aggregated host information.
function getAggregatedHostInfo(host_name)

--! @memberof interface
--! @brief Get all aggregations that have the given host as requester.
--! @details Example if we are looking at the DNS requests, it will return all DNS names requested by host X (host_name). For more information please read the @ref ntop_get_aggregregations_for_host documentation.
--! @tparam string host_name The host name.
--! @return An hashtable containing all aggregations that have the given host as requester.
function getAggregationsForHost(host_name)

--! @memberof interface
--! @brief Get the flow information (minimal details) of network interface.
--! @details For more information please read the @ref ntop_get_interface_flows_info documentation.
--! @return An hashtable containing the flow information of network interface with minimal details.
function getFlowsInfo()

--! @memberof interface
--! @brief Get the flow peers information of network interface.
--! @details For more information please read the @ref ntop_get_interface_flows_peers documentation.
--! @tparam string host_name The host name.
--! @return An hashtable of hashtable containing the flow peers information of network interface.
function getFlowPeers(host_name)

--! @memberof interface
--! @brief Get the flow peers information identified by key of network interface.
--! @details For more information please read the @ref ntop_get_interface_find_flow_by_key documentation.
--! @tparam number key The flow key.
--! @return An hashtable containing the flow information identified by the key parameter of network interface if it exists.
function findFlowByKey(key)

--! @memberof interface
--! @brief Get the host and aggregation information identified by key of network interface.
--! @details For more information please read the @ref ntop_get_interface_find_host documentation.
--! @tparam string key The host key (host name).
--! @return An hashtable containing the flow and aggregation information identified by the key parameter of network interface if it exists.
function findHost(key)

--! @memberof interface
--! @brief Get the ZMQ endpoint of network interface.
--! @details For more information please read the @ref ntop_get_interface_endpoint documentation.
--! @return The endpoint of network interface.
function getEndpoint()

--! @memberof interface
--! @brief Increase interface drops.
--! @details For more information please read the @ref ntop_increase_drops documentation.
--! @tparam drops Number of interface drops to be incremented to interface stats.
function incrDrops(drops)

--! @memberof interface
--! @brief Check if the network interface is running.
--! @details For more information please read the @ref ntop_interface_is_running documentation.
--! @return True if the network interface is defined and running, false otherwise.
function isRunning()

--! @memberof interface
--! @brief Get network interface Id by name.
--! @details For more information please read the @ref ntop_interface_name2id documentation.
--! @tparam string ifname The network interface name.
--! @return The network interface Id, -1 otherwise.
function name2id(if_name)

-- ########################### Ntop lua method ########################### 

--! @memberof ntop
--! @brief Get the ntop path of install and working directory
--! @details For more information please read the @ref ntop_get_dirs documentation.
--! @return An hashtable containing the installed and working directory.
function getDirs()

--! @memberof ntop
--! @brief Get the main ntop information like version, platform, uptime.
--! @details For more information please read the @ref ntop_get_info documentation.
--! @return An hashtable containing the main ntop information.
function getInfo()

--! @memberof ntop
--! @brief Get the uptime information.
--! @details For more information please read the @ref ntop_get_uptime documentation.
--! @return Integer of ntop uptime.
function getUptime()

--! @memberof ntop
--! @brief Dumps the specified file onto the returned web page. Usually it is used to create simple server-side page includes.
--! @details For more information please read the @ref ntop_dump_file documentation.
--! @tparam string path The path of the file to be dumped.
function dumpFile()

--! @memberof ntop
--! @brief Check if ntop is running on windows.
--! @details For more information please read the @ref ntop_is_windows documentation.
--! @return True if ntop is running on windows, false otherwise.
function isWindows()

------------------ REDIS ------------------

--! @memberof ntop
--! @brief Get the redis cache identified by key.
--! @details For more information please read the @ref ntop_get_redis documentation.
--! @tparam string key The redis key.
--! @return The redis cache identified by key, empty string otherwise.
function getCache(key)

--! @memberof ntop
--! @brief Set the redis cache specify the key and the value.
--! @details For more information please read the @ref ntop_set_redis documentation.
--! @tparam string key The redis key.
--! @tparam string value The redis value.
function setCache(key,value)

--! @memberof ntop
--! @brief Delete the redis entry identified by key. Similar to delHashCache() used for hashes.
--! @details For more information please read the @ref ntop_delete_redis_key documentation.
--! @tparam string key The redis key.
function delCache(key)

--! @memberof ntop
--! @brief Get the members of a redis set identified by key.
--! @details For more information please read the @ref ntop_get_set_members_redis documentation.
--! @tparam string key The redis key.
--! @return An hashtabele containing the member of a redis set identified by key if the set exists.
function getMembersCache(key)

--! @memberof ntop
--! @brief Get the value associated with member(field) in the redis hash stored at key.
--! @details For more information please read the @ref ntop_get_hash_redis documentation.
--! @tparam string key The hash key.
--! @tparam string member The hash member.
--! @return The value associated with member(field) in the redis hash stored at key, empty string otherwise.
function getHashCache(key,member)

--! @memberof ntop
--! @brief Sets field in the redis hash stored at key to value. If key does not exist, a new key holding a hash is created. If field already exists in the hash, it is overwritten.
--! @details For more information please read the @ref ntop_set_hash_redis documentation.
--! @tparam string key The hash key.
--! @tparam string member The hash member.
--! @tparam string value The hash value.
function setHashCache(key,member,value)

--! @memberof ntop
--! @brief Delete the specified member(field) from the redis hash stored at key.
--! @details For more information please read the @ref ntop_delete_hash_redis_key documentation.
--! @tparam string key The hash key.
--! @tparam string member The hash member.
function delHashCache(key,member)

--! @memberof ntop
--! @brief Get all field names in the redis hash stored at key.
--! @details For more information please read the @ref ntop_get_hash_keys_redis documentation.
--! @tparam string key The hash key.
--! @return Returns an hashtable containing all field names in the redis hash stored at key.
function getHashKeysCache(key)

--! @memberof ntop
--! @brief Remove the specified hash key from redis. Similar to delCache() but for hash keys.
--! @details For more information please read the @ref ntop_del_hash_redis documentation.
--! @tparam string key The redis hash key.
function delHashCache(key)

--! @memberof ntop
--! @brief Removes and returns a random element from the set value stored at key.
--! @details For more information please read the @ref ntop_get_redis_set_pop documentation.
--! @tparam string set_name The name of the set.
--! @return Random element form the set value stored at key.
function setPopCache(set_name)

--! @memberof ntop
--! @brief Dumps on disk daily stats. This option has effect only of -D and/or -E have been used at ntopng startup.
--! @details For more information please read the @ref ntop_redis_dump_daily_stats documentation.
--! @tparam string day The day in the following format: 131206.
function dumpDailyStats(day)

--! @memberof ntop
--! @brief Get the host id associated with the host name in the hash stored at key.
--! @details If host name does not exist, a new field (host name) and host Id are created. For more information please read the @ref ntop_redis_get_host_id documentation.
--! @tparam string host_name The host name.
--! @return The host id associated with the host name.
function getHostId(host_name)

--! @memberof ntop
--! @brief Returns the number of queued alerts
--! @details Returns the number of queued alerts generated by ntopng and stored in redis
function getNumQueuedAlerts()

--! @memberof ntop
--! @brief Returns the redis queued alerts
--! @tparam integer initial_idx The initial index of the queued alert to return
--! @tparam integer max_num_alerts The maximum number of queued alerts to return.
--! @details Returns up to the the number of queued alerts
function getQueuedAlerts(initial_idx, max_num_alerts)

--! @memberof ntop
--! @brief Returns the redis queued alerts
--! @tparam integer alert_level The alert level. See AlertLevel in ntop_typedefs.h
--! @tparam integer alert_type The alert type. See AlertType in ntop_typedefs.h
--! @tparam string alert_message A string message that describes the alert being reported.
--! @details Returns up to the the number of queued alerts
   function queueAlert(alert_level, alert_type, alert_message)

--! @memberof ntop
--! @brief Get the host name associated with the host id in the hash stored at key.
--! @details If host Id does not exist, a new host key is created. For more information please read the @ref ntop_redis_get_id_to_host documentation.
--! @tparam string host_idx The host Id.
--! @return The host name associated with the host Id.
function getIdToHost(host_idx)

--! @memberof ntop
--! @brief Create the directory tree of the absolute path.
--! @details Do not create devices directory. For more information please read the @ref ntop_mkdir_tree documentation.
--! @tparam string dir The absolute path of directory.
function mkdir(dir)

--! @memberof ntop
--! @brief Sends a string on the system syslog
--! @details Available only on non-Windows systems, it allows a message to be sent to the system syslog. For more information please read the @ref ntop_syslog documentation.
--! @tparam bool msgType Set it to true if this is an error message (LOG_ERR) or informational (LOG_INFO)
--! @tparam string msg The message to send on the syslog.
function syslog(msgType,msg)

--! @memberof ntop
--! @brief Check if the file or directory exists.
--! @details For more information please read the @ref ntop_get_file_dir_exists documentation.
--! @tparam string path The absolute path of file or directory.
--! @return True if exists, false otherwise.
function exists(path)

--! @memberof ntop
--! @brief Scan the input directory and return the list of files.
--! @details For more information please read the @ref ntop_list_dir_files documentation.
--! @tparam string path The absolute path of directory.
--! @return An hastable containing the list of files of the input directory.
function readdir(path)

------------------ ZMQ ------------------

--! @memberof ntop
--! @brief Create and subscribe a new zmq connection.
--! @details For more information please read the @ref ntop_zmq_connect documentation.
--! @tparam string endpoint The endpoint argument is a string consisting of two parts as follows: transport ://address. The transport part specifies the underlying transport protocol to use. The meaning of the address part is specific to the underlying transport protocol selected.
--! @tparam string topic  The option_value argument for the ØMQ socket pointed to by the socket argument.
function zmq_connect(endpoint,topic)

--! @memberof ntop
--! @brief Disconnect, un-subscribe and destroy the context of the zmq connection.
--! @details For more information please read the @ref ntop_zmq_disconnect documentation.
function zmq_disconnect()

--! @memberof ntop
--! @brief Receives a JSON message via ZMQ, parses it and returns it to the caller as Lua hash.
--! @details For more information please read the @ref ntop_zmq_disconnect documentation.
--! @return The received JSON object formatted as Lua hash.
function zmq_receive()

------------------ TIME ------------------

--! @memberof ntop
--! @brief Get the system time.
--! @details For more information please read the @ref ntop_gettimemsec documentation.
--! @return The system time.
function gettimemsec()

------------------ TRACE ------------------

--! @memberof ntop
--! @brief Check if the trace level of ntop is set to verbose.
--! @details For more information please read the @ref ntop_verbose_trace documentation.
--! @return True if the ntop trace level is set to @ref MAX_TRACE_LEVEL, false otherwise.
function verboseTrace()

------------------ RRD ------------------
--! @memberof ntop
--! @brief Creates a RRD (Round-Robin Database) archive
--! @details For more information please read the @ref ntop_rrd_create documentation.
--! @tparam string param The RRD create parameters as required by RRD
function rrd_create(param)

--! @memberof ntop
--! @brief Updates a RRD (Round-Robin Database) archive
--! @details For more information please read the @ref ntop_rrd_update documentation.
--! @tparam string path The RRD archive file path
--! @tparam string param RRD update parameters
function rrd_update(path, param)

--! @memberof ntop
--! @brief Fetches a set value from the specified RRD archive
--! @details For more information please read the @ref ntop_rrd_fetch documentation.
--! @tparam string param The RRD update parameters as required by RRD
function rrd_fetch(param)

------------------ PREFS ------------------

--! @memberof ntop
--! @brief Get the values of ntop preferences.
--! @details For more information please read the @ref ntop_get_prefs documentation.
--! @return An hashtable containing the values of ntop preferences.
function getPrefs()

------------------ ADMIN ------------------

--! @memberof ntop
--! @brief Get the ntop users information.
--! @details For more information please read the @ref ntop_get_users documentation.
--! @return An hashtable containing the users information.
function getUsers()

--! @memberof ntop
--! @brief Get the user group.
--! @details Return the stored group for the given user.
--! @return The user group.
function getUserGroup()

--! @memberof ntop
--! @brief Get the user allowed networks.
--! @details Return the stored allowed netwroks (i.e. the networks this user can see) for the given user.
--! @return The user allowed networks
function getAllowedNetworks()

--! @memberof ntop
--! @brief Reset the user password.
--! @details Check the old password and update the user info with the new password.For more information please read the @ref ntop_reset_user_password documentation.
--! @tparam string username The username.
--! @tparam string old_password The hold password.
--! @tparam string new_password The new password.
function resetUserPassword(username,old_password,new_password)

--! @memberof ntop
--! @brief Change the user role.
--! @details Set if the user is a standard one or an Admin. TODO: documentation 
--! @tparam string username The username.
--! @tparam string user_role The user role
function changeUserRole(username,user_role)

--! @memberof ntop
--! @brief Change the list of allowed networks
--! @details Set the networks that the user is allowed to inspect. TODO: documentation
--! @tparam string username The username.
--! @tparam string allowed_nets: comma separated list of networks
function changeAllowedNets(username,allowed_nets)

--! @memberof ntop
--! @brief Add new user.
--! @details For more information please read the @ref ntop_add_user documentation.
--! @tparam string username The username.
--! @tparam string full_name The name of users.
--! @tparam string password The user password.
--! @tparam string host_role The group of user.
--! @tparam string allowed_networks The networks that the user can view.
function addUser(username,full_name,password,host_role,allowed_networks)

--! @memberof ntop
--! @brief Delete an existing user.
--! @details For more information please read the @ref ntop_delete_user documentation.
--! @tparam string username The username.
function deleteUser(username)

------------------ ADDRESS RESOLUTION ------------------

--! @memberof ntop
--! @brief Resolve the IP address and get host name.
--! @details For more information please read the @ref ntop_resolve_address documentation.
--! @tparam string numIP The IP address.
--! @return The host name of IP address.
function resolveAddress(numIP)

--! @memberof ntop
--! @brief Get the resolved address in the redis cache stored at key.
--! @details For more information please read the @ref ntop_get_resolved_address documentation.
--! @tparam string key The IP address.
--! @return The host name of IP address.
function getResolvedAddress(key)



