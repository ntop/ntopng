Lua C API
=========

The Lua C API consists of two main objects:

    - the `ntop` object is used to access global ntopng functions, which are
      not bound to a specific network interface

    - the `interface` object is used to access a specific network interface functions.

For example, the flows information is a network interface specific information,
so it's available through the interface object API via `interface.getFlowsInfo()`.

.. toctree::
    :maxdepth: 2
    :numbered:

    ntop/index
    interface/index
