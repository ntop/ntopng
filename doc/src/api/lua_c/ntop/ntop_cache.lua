--! @brief Get a temporary cached value identified by its key.
--! @param key the item identifier.
--! @return item value on success, nil otherwise.
--! @note an empty string is returned if the key is not found.
function ntop.getCache(string key)

--! @brief Set a temporary cached value identified by a key.
--! @param key the item identifier.
--! @param value the item value.
--! @param expire_secs if set, the cache will expire after the specified seconds.
--! @note by convention, cache keys should start with "ntopng.cache." .
function ntop.setCache(string key, string value, int expire_secs=nil)

--! @brief Delete a previously cached value.
--! @param key the item identifier.
function ntop.delCache(string key)

--! @brief Atomically increase a cached counter and get its new value.
--! @param key the item identifier.
--! @param amount the counter increment.
--! @return the new counter value
--! @note the counter starts from 0 for newly created keys.
function ntop.incrCache(string key, int amount=1)
