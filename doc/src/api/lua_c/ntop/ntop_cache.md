---
title: "Cache API"
description: "The cache API provides a temporary key-value based storage. Cache API in the ntopng User's Guide."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# Cache API {#cache-api}

The cache API provides a temporary key-value based storage.

### `ntop.getCache(string key)` {#ntop-getcache}

Get a temporary cached value identified by its key.

**Parameters**

- `key`: the item identifier.

**Returns**: item value on success, nil otherwise.

::: info
an empty string is returned if the key is not found.
:::

### `ntop.setCache(string key, string value, int expire_secs=nil)` {#ntop-setcache}

Set a temporary cached value identified by a key.

**Parameters**

- `key`: the item identifier.
- `value`: the item value.
- `expire_secs`: if set, the cache will expire after the specified seconds.

::: info
by convention, cache keys should start with "ntopng.cache." .
:::

### `ntop.delCache(string key)` {#ntop-delcache}

Delete a previously cached value.

**Parameters**

- `key`: the item identifier.

### `ntop.incrCache(string key, int amount=1)` {#ntop-incrcache}

Atomically increase a cached counter and get its new value.

**Parameters**

- `key`: the item identifier.
- `amount`: the counter increment.

**Returns**: the new counter value

::: info
the counter starts from 0 for newly created keys.
:::
