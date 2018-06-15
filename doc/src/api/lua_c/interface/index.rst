interface
=========

A Lua script is associated with a network interface, called *active interface*.
All the interface methods are referred to the *active interface*.
By calling `interface.select()` it's possible to change the current *active interface*
of the script.

For example, in order to extract local hosts information for interface eth0, the
following snippet would be used:

.. code-block:: lua

  interface.select("eth0")

  -- working on eth0 from now on

  local res = interface.getLocalHostsInfo()
  -- tprint(res)

.. toctree::
    :maxdepth: 2

    interface_hosts
    interface_flows
    interface_misc
    interface_macs
    interface_ndpi
    interface_dump
