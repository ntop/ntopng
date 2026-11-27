---
title: "Lua API"
description: "The ntopng core provides a LuaAPI to interact with it. The API is internally used"
outline: [2, 3]
lastUpdated: 2022-11-25T12:32:17+01:00
---
# Lua API {#lua-api}

The ntopng core provides a LuaAPI to interact with it. The API is internally used
by periodic scripts and GUI scripts to extract information or to apply configuration
changes.

Custom checks can use the API, for example, to provide new data visualizations
or extract the data to send it to an external program.

Since some API functions can return very complex objects, which will not be covered here,
the suggestion is to use the utility function `tprint` to print out the result a the function
to figure out its format.

The Lua C API consists of two main objects:

> - the `ntop` object is used to access global ntopng functions, which are
>   not bound to a specific network interface.
> - the `interface` object is used to access a specific network interface functions.

For example, the flows information is a network interface specific information,
so it's available through the interface object API via `interface.getFlowsInfo()`.

- [1. ntop Lua Object](/api/lua_c/ntop/index.md)
  - [1.1. Cache API](/api/lua_c/ntop/ntop_cache.md)
  - [1.2. Prefs API](/api/lua_c/ntop/ntop_prefs.md)
  - [1.3. Filesystem API](/api/lua_c/ntop/ntop_fs.md)
  - [1.4. Network API](/api/lua_c/ntop/ntop_network.md)
  - [1.5. Users API](/api/lua_c/ntop/ntop_users.md)
  - [1.6. Misc API](/api/lua_c/ntop/ntop_misc.md)
- [2. interface Lua Object](/api/lua_c/interface/index.md)
  - [2.1. Hosts API](/api/lua_c/interface/interface_hosts.md)
  - [2.2. Flows API](/api/lua_c/interface/interface_flows.md)
  - [2.3. Misc API](/api/lua_c/interface/interface_misc.md)
  - [2.4. MACs API](/api/lua_c/interface/interface_macs.md)
  - [2.5. nDPI API](/api/lua_c/interface/interface_ndpi.md)
  - [2.6. Dump API](/api/lua_c/interface/interface_dump.md)
- [3. Host Checks](/api/lua_c/host_checks/index.md)
  - [3.1. Operational Mode](/api/lua_c/host_checks/index.md#operational-mode)
  - [3.2. Script Example](/api/lua_c/host_checks/index.md#script-example)
  - [3.3. Host Object Methods](/api/lua_c/host_checks/index.md#host-object-methods)
- [4. Flow Checks](/api/lua_c/flow_checks/index.md)
  - [4.1. Script Format](/api/lua_c/flow_checks/index.md#script-format)
  - [4.2. Flow Filters](/api/lua_c/flow_checks/index.md#flow-filters)
  - [4.3. Alerts](/api/lua_c/flow_checks/index.md#alerts)
  - [4.4. Helpers](/api/lua_c/flow_checks/index.md#helpers)
  - [4.5. Flow Object Methods](/api/lua_c/flow_checks/index.md#flow-object-methods)
  - [4.6. Writing Custom Flow Scripts: Guide and Examples](/api/lua_c/flow_checks/examples.md)
- [5. Interface Checks](/api/lua_c/interface_checks/index.md)
- [6. Network Checks](/api/lua_c/network_checks/index.md)

