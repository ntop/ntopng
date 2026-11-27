---
title: "ntop Lua Object"
description: "The ntop object exposes global utility functions which are not bound to a specific"
outline: [2, 3]
lastUpdated: 2022-11-25T12:00:10+01:00
---
# ntop Lua Object {#ntop-lua-object}

The ntop object exposes global utility functions which are not bound to a specific
network interface.

Here is some example of recurrent functions calls:

```lua
-- An URL
print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/if_stats.lua">interface stats</a>]]

-- A POST form
print[[<form method="POST">
  <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
  <input name="my_custom_value" value="1" />
</form>]]

-- Set a persistent preference
ntop.setPref("ntopng.prefs.my_custom_pref", "my_custom_value")

-- Get a persistent preference
local res = ntop.getPref("ntopng.prefs.my_custom_pref")

-- tprint(res)
```

- [1.1. Cache API](/api/lua_c/ntop/ntop_cache.md)
- [1.2. Prefs API](/api/lua_c/ntop/ntop_prefs.md)
- [1.3. Filesystem API](/api/lua_c/ntop/ntop_fs.md)
- [1.4. Network API](/api/lua_c/ntop/ntop_network.md)
- [1.5. Users API](/api/lua_c/ntop/ntop_users.md)
- [1.6. Misc API](/api/lua_c/ntop/ntop_misc.md)

