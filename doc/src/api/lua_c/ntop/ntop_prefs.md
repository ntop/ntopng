---
title: "Prefs API"
description: "The Prefs API provides key-value based persistent storage. Prefs API in the ntopng User's Guide."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# Prefs API {#prefs-api}

The Prefs API provides key-value based persistent storage.

### `ntop.setPref(string key, string value)` {#ntop-setpref}

Set a persistent preference.

**Parameters**

- `key`: the preference key.
- `value`: the preference value.

::: info
by convention, preference keys should start with "ntopng.prefs." .
:::

### `ntop.getPref(string key)` {#ntop-getpref}

Get a persistent preference.

**Parameters**

- `key`: the preference key.

**Returns**: preference value on success, nil otherwise.

::: info
an empty string is returned if the key is not found.
:::

### `ntop.getPrefs()` {#ntop-getprefs}

Retrieve many ntopng preferences.

**Returns**: table (pref_name -> pref_value).

### `ntop.flushCache()` {#ntop-flushcache}

Completely flushes any preference and cached value.

**Returns**: true on success, false otherwise.

### `ntop.listIndexCache(string key, int index)` {#ntop-listindexcache}

Retrieve a specific item in a Redis list.

**Parameters**

- `key`: the list item identifier.
- `index`: the list index.

**Returns**: the item on success, nil otherwise.

::: info
this is equivalent to the lindex operation (https://redis.io/commands/lindex)
:::

### `ntop.lpushCache(string queue_name, string value, int trim_size=nil)` {#ntop-lpushcache}

Left push a persistent value on a queue.

**Parameters**

- `queue_name`: the queue name.
- `value`: the value to push.
- `trim_size`: the maximum number of elements to keep in the queue.

### `ntop.rpushCache(string queue_name, string value, int trim_size=nil)` {#ntop-rpushcache}

Right push a persistent value on a queue.

**Parameters**

- `queue_name`: the queue_name name.
- `value`: the value to push.
- `trim_size`: the maximum number of elements to keep in the queue.

### `ntop.lpopCache(string queue_name)` {#ntop-lpopcache}

Left pop a value from a persistent queue.

**Parameters**

- `queue_name`: the queue_name name.

**Returns**: the poped value on success, nil otherwise.

### `ntop.rpopCache(string queue_name)` {#ntop-rpopcache}

Right pop a value from a persistent queue.

**Parameters**

- `queue_name`: the queue_name name.

**Returns**: the poped value on success, nil otherwise.

### `ntop.lremCache(string queue_name, string item)` {#ntop-lremcache}

Removes the first of the item in the queue.

**Parameters**

- `queue_name`: the queue_name name.
- `item`: the item to remove.

**Returns**: true on success, false otherwise.

### `ntop.ltrimCache(string queue_name, int start_idx, int end_idx)` {#ntop-ltrimcache}

Modify a persistent queue to only keep the items within the specified index range.

**Parameters**

- `queue_name`: the queue_name name.
- `start_idx`: the lower index for item range.
- `end_idx`: the upper index for item range.

### `ntop.lrangeCache(string queue_name, int start_idx=0, int end_idx=-1)` {#ntop-lrangecache}

Retrieves items from a persistent queue at the specified index range.

**Parameters**

- `queue_name`: the queue_name name.
- `start_idx`: the lower index for item range.
- `end_idx`: the upper index for item range.

**Returns**: table with retrieved item on success, nil otherwise.

### `ntop.llenCache(string queue_name)` {#ntop-llencache}

Get the length of a queue.

**Parameters**

- `queue_name`: the queue_name name.

**Returns**: the queue length.

### `ntop.setMembersCache(string set_name, string value)` {#ntop-setmemberscache}

Insert the specified value into the set.

**Parameters**

- `set_name`: the name of the set.
- `value`: the item value to insert. This is unique within the set.

### `ntop.delMembersCache(string set_name, string value)` {#ntop-delmemberscache}

Remove the specified value from the set.

**Parameters**

- `set_name`: the name of the set.
- `value`: the item value to remove.

### `ntop.getMembersCache(string set_name)` {#ntop-getmemberscache}

Get all the members of the specified set.

**Parameters**

- `set_name`: the name of the set.

**Returns**: set members on success, nil otherwiser.

### `ntop.getHashCache(string map_name, string item_key)` {#ntop-gethashcache}

Retrieve a value from a persistent key-value map.

**Parameters**

- `map_name`: the name of the map.
- `item_key`: the name of the map.

**Returns**: item value on success, nil otherwise.

::: info
an empty string is returned if the key is not found.
:::

### `ntop.setHashCache(string map_name, string item_key, string item_value)` {#ntop-sethashcache}

Store a value into a persistent key-value map.

**Parameters**

- `map_name`: the name of the map.
- `item_key`: the item key within the map.
- `item_value`: the item value to store.

::: info
If an item for the specified key already exists, it will be replaced.
:::

### `ntop.delHashCache(string map_name, string item_key)` {#ntop-delhashcache}

Delete a value from a persistent key-value map.

**Parameters**

- `map_name`: the name of the map.
- `item_key`: the item key within the map.

### `ntop.getHashKeysCache(string map_name)` {#ntop-gethashkeyscache}

Retrieve all the keys of the specified persistent key-value map.

**Parameters**

- `map_name`: the name of the map.

**Returns**: table (key -> "") on success, nil otherwise.

### `ntop.getHashAllCache(string map_name)` {#ntop-gethashallcache}

Retrieve all the key-value pairs of the specified persistent key-value map.

**Parameters**

- `map_name`: the name of the map.

**Returns**: table (key -> value) on success, nil otherwise.

### `ntop.getKeysCache(string pattern)` {#ntop-getkeyscache}

Retrieve all the preferences and cached keys matching the specified pattern.

**Parameters**

- `pattern`: the string to search into the keys.

**Returns**: table (key -> "") of matched keys on success, nil otherwise.
