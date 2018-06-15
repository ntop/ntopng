--! @brief Set a persistent preference.
--! @param key the preference key.
--! @param key the preference value.
function setPref(string key, string value)

--! @brief Get a persistent preference.
--! @param key the preference key.
--! @return preference value on success, nil otherwise.
--! @note an empty string is returned if the key is not found.
function getPref(string key)

--! @brief Retrieve many ntopng preferences.
--! @return table (pref_name -> pref_value).
function getPrefs()

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
