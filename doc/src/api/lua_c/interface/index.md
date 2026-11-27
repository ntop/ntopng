---
title: "interface Lua Object"
description: "A Lua script is associated with a network interface, called active interface. All the interface methods are referred to the active interface."
outline: [2, 3]
lastUpdated: 2022-11-25T12:00:10+01:00
---
# interface Lua Object {#interface-lua-object}

A Lua script is associated with a network interface, called *active interface*.
All the interface methods are referred to the *active interface*.
By calling `interface.select()` it's possible to change the current *active interface*
of the script.

For example, in order to extract local hosts information for interface eth0, the
following snippet would be used:

```lua
interface.select("eth0")

-- working on eth0 from now on

local res = interface.getLocalHostsInfo()
-- tprint(res)
```

- [2.1. Hosts API](/api/lua_c/interface/interface_hosts.md)
- [2.2. Flows API](/api/lua_c/interface/interface_flows.md)
- [2.3. Misc API](/api/lua_c/interface/interface_misc.md)
- [2.4. MACs API](/api/lua_c/interface/interface_macs.md)
- [2.5. nDPI API](/api/lua_c/interface/interface_ndpi.md)
- [2.6. Dump API](/api/lua_c/interface/interface_dump.md)


Rather than using the `interface` API directly, one can use Lua
wrappers to process hosts, flows and other elements in
batches. Processing in batches has the benefit of reduced memory
footprint and thus it may be absolutely necessary when working in large
environments.

For example, to visit all the active flows in batches using the Lua
wrapper, the following snippet of code can be used:

```lua
local count = 0

callback_utils.foreachFlow("eno1", os.time() + 10,
  function(flow_num, flow)
    count = count + 1
    return true -- continue
  end
)

io.write("total flows: "..count.."\n")
```

The full list of wrappers is available at
<https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/callback_utils.lua>
