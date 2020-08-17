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

Rather than using the :code:`interface` API directly, one can use Lua
wrappers to process hosts, flows and other elements in
batches. Processing in batches has the benefit of reduced memory
footprint and thus it may be absolutely necessary when working in large
environments.

For example, to visit all the active flows in batches using the Lua
wrapper, the following snippet of code can be used:

.. code-block:: lua

  local count = 0

  callback_utils.foreachFlow("eno1", os.time() + 10,
    function(flow_num, flow)
      count = count + 1
      return true -- continue
    end
  )

  io.write("total flows: "..count.."\n")
   
The full list of wrappers is available at
https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/callback_utils.lua
