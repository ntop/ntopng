Lua API
=========

The ntopng core provides a LuaAPI to interact with it. The API is internally used
by periodic scripts and GUI scripts to extract information or to apply configuration
changes.

Custom checks can use the API, for example, to provide new data visualizations
or extract the data to send it to an external program.

Since some API functions can return very complex objects, which will not be covered here,
the suggestion is to use the utility function `tprint` to print out the result a the function
to figure out its format.

The Lua C API consists of two main objects:

    - the `ntop` object is used to access global ntopng functions, which are
      not bound to a specific network interface.

    - the `interface` object is used to access a specific network interface functions.

For example, the flows information is a network interface specific information,
so it's available through the interface object API via `interface.getFlowsInfo()`.

.. toctree::
    :maxdepth: 2
    :numbered:

    ntop/index
    interface/index
    host_checks/index
    flow_checks/index
    interface_checks/index
    network_checks/index
