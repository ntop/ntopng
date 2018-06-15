---------------------------------
--! @file
--! @brief The 'ntop' object API.
---------------------------------

--! @brief Get ntopng directory information.
--! @return table (installdir, workingdir, scriptdir, httpdocsdir, callbacksdir).
function getDirs()

--! @brief Get ntopng status information.
--! @return ntopng information.
function getInfo()

--! @brief Get seconds from ntopng startup.
--! @return ntopng uptime in seconds.
function getUptime()

--! @brief Get ntopng host statistics.
--! @return table (cpu_load, cpu_idle, mem_total, mem_free, mem_buffers, mem_cached, mem_shmem. mem_used).
function systemHostStat()

--! @brief Get a cached value identified by its key.
--! @param key the item identifier.
--! @return item value on success, nil otherwise.
--! @note an empty string is returned if the key is not found.
function getCache(string key)

--! @brief Set a cached value identified by a key.
--! @param key the item identifier.
--! @param value the item value.
--! @param expire_secs if set, the cache will expire after the specified seconds.
function setCache(string key, string value, int expire_secs=nil)

--! @brief Delete a previously cached value.
--! @param key the item identifier.
function delCache(string key)

--! @brief Completely flushes any preference and cached value.
--! @return true on success, false otherwise.
function flushCache()

--! @brief Left push a persistent value on a queue.
--! @param queue_name the queue name.
--! @param value the value to push.
--! @param trim_size the maximum number of elements to keep in the queue.
function lpushCache(string queue_name, string value, trim_size=nil)

--! @brief Right push a persistent value on a queue.
--! @param queue_name the queue_name name.
--! @param value the value to push.
--! @param trim_size the maximum number of elements to keep in the queue.
function rpushCache(string queue_name, string value, trim_size=nil)

--! @brief Left pop a value from a persistent queue.
--! @param queue_name the queue_name name.
--! @return the poped value on success, nil otherwise.
function lpopCache(string queue_name)

--! @brief Modify a persistent queue to only keep the items within the specified index range.
--! @param queue_name the queue_name name.
--! @param start_idx the lower index for item range.
--! @param end_idx the upper index for item range.
function ltrimCache(string queue_name, int start_idx, int end_idx)

--! @brief Retrieves items from a persistent queue at the specified index range.
--! @param queue_name the queue_name name.
--! @param start_idx the lower index for item range.
--! @param end_idx the upper index for item range.
--! @return table with retrieved item on success, nil otherwise.
function lrangeCache(string queue_name, int start_idx=0, int end_idx=-1)

--! @brief Insert the specified value into the set.
--! @param set_name the name of the set.
--! @param value the item value to insert. This is unique within the set.
function setMembersCache(string set_name, string value)

--! @brief Remove the specified value from the set.
--! @param set_name the name of the set.
--! @param value the item value to remove.
function delMembersCache(string set_name, string value)

--! @brief Get all the members of the specified set.
--! @param set_name the name of the set.
--! @return set members on success, nil otherwiser.
function getMembersCache(string set_name)

--! @brief Retrieve a value from a persistent key-value map.
--! @param map_name the name of the map.
--! @param item_key the name of the map.
--! @return item value on success, nil otherwise.
--! @note an empty string is returned if the key is not found.
function getHashCache(string map_name, string item_key)

--! @brief Store a value into a persistent key-value map.
--! @param map_name the name of the map.
--! @param item_key the item key within the map.
--! @param item_value the item value to store.
--! @note If an item for the specified key already exists, it will be replaced.
function setHashCache(string map_name, string item_key, string item_value)

--! @brief Delete a value from a persistent key-value map.
--! @param map_name the name of the map.
--! @param item_key the item key within the map.
function delHashCache(string map_name, string item_key)

--! @brief Retrieve all the keys of the specified persistent key-value map.
--! @param map_name the name of the map.
--! @return table (key -> "") on success, nil otherwise.
function getHashKeysCache(string map_name)

--! @brief Retrieve all the key-value pairs of the specified persistent key-value map.
--! @param map_name the name of the map.
--! @return table (key -> value) on success, nil otherwise.
function getHashAllCache(string map_name)

--! @brief Retrieve all the preferences and cached keys matching the specified pattern.
--! @param pattern the string to search into the keys.
--! @return table (key -> "") of matched keys on success, nil otherwise.
function getKeysCache(string pattern)

--! @brief Add a network to the ntopng local networks list.
--! @param network_cidr the network to add in CIDR format.
function addLocalNetwork(string network_cidr)

--! @brief Set a persistent preference.
--! @param key the preference key.
--! @param key the preference value.
function setPref(string key, string value)

--! @brief Get a persistent preference.
--! @param key the preference key.
--! @return preference value on success, nil otherwise.
--! @note an empty string is returned if the key is not found.
function getPref(string key)

--! @brief Check if the specified path is a directory.
--! @param path to check.
--! @return true if it's a direcory, false otherwise.
function isdir(string path)

--! @brief Create the specified directory structure.
--! @param path the directory tree to create.
--! @return true on success, false otherwise.
function mkdir(string path)

--! @brief Check if the specified file is not empty.
--! @param filename the file to check.
--! @return true if file is not empty, false otherwise.
function notEmptyFile(string filename)

--! @brief Check if the specified file or directory exists.
--! @param path the path to check.
--! @return true if the path exists, false otherwise.
function exists(string path)

--! @brief Get the last time the specified file has changed.
--! @param filename the file to query.
--! @return last modification time on success, -1 otherwise.
function fileLastChange(string filename)

--! @brief List directory files and dirs contents.
--! @param path the directory to traverse.
--! @return table (entry_name -> entry_name) on success, nil otherwise.
function readdir(string path)

--! @brief Recursively remove a file or directory.
--! @param path the path to remove.
function rmdir(string path)

--! @brief Get the ntopng local networks list.
--! @return table (network_address -> "").
function getLocalNetworks()

--! @brief Get the current time in milliseconds.
--! @return the current miliiseconds time.
function gettimemsec()

--! @brief Check if verbose trace is enabled.
--! @return true if verborse trace is enabled, false otherwise.
function verboseTrace()

--! @brief Send raw UDP data to a given host and port.
--! @param host the host IP address.
--! @param port the host port.
--! @param data the data to send.
function send_udp_data(string host, int port, string data)

--! @brief This is the equivalent C inet_ntoa for Lua.
--! @param numeric_ip the numeric IP address to convert.
--! @return the symbolic IP address.
function inet_ntoa(int numeric_ip)

--! @brief Apply a netmask to the specified IP address.
--! @param address the IP address.
--! @param netmask the network mask to apply.
--! @return the masked IP address.
function networkPrefix(string address, int netmask)

--! @brief Retrieve many ntopng preferences.
--! @return table (pref_name -> pref_value).
function getPrefs()

--! @brief Send an HTTP redirection header to the specified URL.
--! @param url the URL to redirect to.
--! @note this must be called before sending any other HTTP data.
function httpRedirect(string url)

--! @brief Performs an HTTP GET request to the specified URL.
--! @param url the URL to fetch.
--! @param username for HTTP authentication.
--! @param pwd the password for HTTP authentication.
--! @param timeout maximum connection timeout in seconds.
--! @param return_content enable sending response content back to the caller.
--! @return table (RESPONSE_CODE, CONTENT_TYPE, EFFECTIVE_URL), with additional CONTENT and CONTENT_LEN if return_content is enabled on success, nil otherwise.
function httpGet(string url, string username=nil, string pwd=nil, int timeout=nil, bool return_content=false)

--! @brief Get the ntopng HTTP prefix.
--! @details The HTTP prefix is the initial part of the ntopng URL, which consists of HTTP host, port and optionally a user-defined prefix. Any URL within ntopng should include this prefix.
--! @return the HTTP prefix.
function getHttpPrefix()

--! @brief Get ntopng users information.
--! @return ntopng users information.
function getUsers()

--! @brief Get the group of the current ntopng user.
--! @return the user group.
function getUserGroup()

--! @brief Get a string representing the networks the current ntopng user is allowed to see.
--! @return allowed networks string.
function getAllowedNetworks()

--! @brief Reset a ntopng user password.
--! @param who the ntopng user who is requesting the reset.
--! @param username the user for the password reset.
--! @param old_password the old user password.
--! @param new_password the new user password.
--! @note the administrator can reset the password regardless of the old_password value.
--! @return true on success, false otherwise.
function resetUserPassword(string who, string username, string old_password, string new_password)

--! @brief Change the group of a ntopng user.
--! @param username the target user.
--! @param user_role the new group, should be "unprivileged" or "administrator".
--! @return true on success, false otherwise.
function changeUserRole(string username, string user_role)

--! @brief Change the allowed networks of a ntopng user.
--! @param username the target user.
--! @param allowed_networks the new allowed networks.
--! @return true on success, false otherwise.
function changeAllowedNets(string username, string allowed_networks)

--! @brief Change the allowed interface name of a ntopng user.
--! @param username the target user.
--! @param allowed_ifname the new allowed interface name for the user.
--! @return true on success, false otherwise.
function changeAllowedIfname(string username, string allowed_ifname)

--! @brief Change the gui language of a ntopng user.
--! @param username the target user.
--! @param language the new language code.
--! @return true on success, false otherwise.
function changeUserLanguage(string username, string language)

--! @brief Add a new ntopng user.
--! @param username the user name to add.
--! @param full_name a descriptive user name.
--! @param password the user password.
--! @param host_role the user group, should be "unprivileged" or "administrator".
--! @param allowed_networks comma separated list of allowed networks for the user. Use "0.0.0.0/0,::/0" for all networks.
--! @param host_pool_id this can be used to create a Captive Portal user.
--! @param language user language code.
--! @return true on success, false otherwise.
function addUser(string username, string full_name, string password, string host_role, string allowed_networks, string allowed_interface, string host_pool_id=nil, string language=nil)

--! @brief Delete a ntopng user.
--! @param username the user to delete.
--! @return true on success, false otherwise.
function deleteUser(string username)

--! @brief Check if the ntopng gui login is disable.
--! @return true if login is disabled, false otherwise.
function isLoginDisabled()

--! @brief Retrieves a ntopng local network by its id.
--! @param network_id the local network id.
--! @return the network address on success, an empty string otherwise.
function getNetworkNameById(int network_id)

--! @brief Generate a random value to prevent CSRF and XSRF attacks.
--! @return the token value.
--! @note Any HTTP POST request must contain a "csrf" field with a token value generated by a call to this function.
function getRandomCSRFValue()

--! @brief Send an HTTP POST request with json content.
--! @param username for HTTP authentication. Pass empty string to disable authentication.
--! @param password for HTTP authentication. Pass empty string to disable authentication.
--! @param url the target URL.
--! @param json the data to post.
--! @return true on success, false otherwise.
--! @note HTTP header "Content-Type: application/json" is sent.
function postHTTPJsonData(string username, string password, string url, string json)

--! @brief Send an HTTP POST request with url encoded data.
--! @param username for HTTP authentication. Pass empty string to disable authentication.
--! @param password for HTTP authentication. Pass empty string to disable authentication.
--! @param url the target URL.
--! @param data the url encoded data to send.
--! @return true on success, false otherwise.
function postHTTPform(string username, string password, string url, string data)

--! @brief Send an HTTP POST request with a file contents.
--! @param username for HTTP authentication. Pass empty string to disable authentication.
--! @param password for HTTP authentication. Pass empty string to disable authentication.
--! @param url the target URL.
--! @param path the source file path.
--! @param delete_file_after_post if true, source file is deleted after a successful POST.
--! @return true on success, nil otherwise.
--! @note HTTP header "Content-Type: text/plain; charset=utf-8" is sent.
function postHTTPTextFile(string username, string password, string url, string path, bool delete_file_after_post=false)

--! @brief Send a message to syslog.
--! @param is_error if true, level will be LOG_ERR, otherwise LOG_INFO.
--! @param message the message to send.
function syslog(bool is_error, string message)

--! @brief Set ntopng logging level.
--! @param level one of "trace", "debug", "info", "normal", "warning", "error".
function setLoggingLevel(string level)

--! @brief Log a message.
--! @param msg the message to log.
--! @note Message will be logged with "normal" level.
function traceEvent(string msg)

--! @brief Check if ntopng has seen any VLAN tagged traffic.
--! @return true if VLAN traffic has been seen, false otherwise.
function hasVLANs()

--! @brief Check if ntopng has Geo IP support available.
--! @return true if Geo IP is available, false otherwise.
function hasGeoIP()

--! @brief Check if the operating system is Windows.
--! @return true if Windows, false otherwise.
function isWindows()

--! @brief A wrapper for C getservbyport.
--! @param port service port.
--! @param proto service protocol, e.g. "tcp".
--! @return getservbyport result on success, the port value on failure.
function getservbyport(int port, string proto)

--! @brief Sleep with milliseconds accuracy.
--! @param duration in milliseconds.
function msleep(int duration)

--! @brief Get the manufacturer name from mac address.
--! @param mac the MAC address.
--! @return table(short, extended) on success, nil otherwise.
function getMacManufacturer(string mac)

--! @brief Get information about the currest host.
--! @return table (ip, instance_name).
function getHostInformation()

--! @brief Check if ntopng is shuttind down.
--! @return true if is shuttting down, false otherwise.
function isShutdown()
