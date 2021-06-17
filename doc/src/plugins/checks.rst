.. _User Scripts:

User Scripts
============

User scripts are the core of plugins. They actually allow certain
actions to be performed periodically, or when a certain event
occurs. The logic of a plugin is contained in its users
scripts. A plugin contains zero to many user scripts.

Structure
---------

The structure of a user script is the following:

.. code:: lua

  local checks = require("checks")

  -- #################################################################

  local script = {
    hooks = {},

    -- other script attributes ...
  }

  -- #################################################################

  function script.setup()
    -- return false to disable the script
    return true
  end

  -- #################################################################

  return(script)


Every user script must return a Lua table with the following keys:

  - :code:`hooks`: a Lua table with hook names as key and callbacks as values. :ref:`User Script Hooks` are events or points in time. ntopng uses hooks to know when to call a user script. A user script defining a hook will get the hook callaback called by ntopng. User scripts must register to at least one hook. See :ref:`User Script Hooks`.
  - :code:`gui`: a Lua table specifying user script name, description and configuration. Data is used by ntopng to show the user script configurable from the :ref:`Web GUI`.
  - :code:`packet_interface_only` (optional): only execute the script on packet interfaces, excluding ZMQ interfaces.
  - :code:`nedge_only` (optional): if true, the script is only executed in nEdge.
  - :code:`nedge_exclude` (optional): if true, the script is not executed in nEdge.
  - :code:`default_value` (optional): the default value for the script configuration, in the form :code:`<script_key>;<operator>;<value>`
    (e.g. :code:`syn_flood_victim;gt;50`). See :ref:`Web GUI`.
  - :code:`default_enabled` (optional): if false, the script is disabled by default.

Furthermore, a script may define the following extra functions, which are only called once per script:

  - :code:`setup()`: called once per user script. If it returns :code:`false` then the script is considered
    disabled and its hooks are not be called.
  - :code:`teardown()`: called after the script operation is complete (e.g. after all the hosts have been iterated and hooks called).

.. _Flow User Scripts:

Flow User Scripts
-----------------

Flow user scripts are executed on each network flow directly from the C++ with flow callbacks. The user script have access to flow information such as L4 and L7 protocols, peers involved in the communication, and other things.
This information can be retrieved via the `Flow User Scripts API`_.

Refer to :ref:`Flow User Script Hooks` for available hooks.

.. _`Flow User Scripts API`: ../api/lua_c/flow_checks/index.html

ntopng supports users scripts for the following traffic elements:

  - :code:`interface`: a network interface of ntopng. Check out the `Interface User Scripts API`_.
  - :code:`network`: a local network of ntopng. Check out the `Network User Scripts API`_.
  - :code:`system`: the system on top of which is running ntopng
  - :code:`SNMP interfaces`: interfaces of monitored SNMP devices

Refer to :ref:`Other User Script Hooks` for available hooks.

.. _`Interface User Scripts API`: ../api/lua_c/interface_checks/index.html
.. _`Network User Scripts API`: ../api/lua_c/network_checks/index.html

Syslog User Scripts
-------------------

Syslog scripts are used to handle syslog events and ingest data,
including flows and alerts, from external sources (e.g. alerts from
Intrusion Detection Systems).

Scripts Location
~~~~~~~~~~~~~~~~

Syslog scripts are located under
:code:`/usr/share/ntopng/scripts/callbacks/syslog` and should use the
source name (e.g. application name) with the :code:`.lua` extension as
file name. In fact messages demultiplexing is implemented by using the
source name for matching the script name. For example, log messages
coming from :code:`suricata` will be delivered to the
:code:`/usr/share/ntopng/scripts/callbacks/syslog/suricata.lua`
script.

Script API
~~~~~~~~~~

A syslog module shoule implement the below functions:

 - :code:`setup` (optional) which is called once to initialize the module.
 - :code:`teardown` (optional) which is called once to terminate the module.
 - :code:`hooks.handleEvent` which is called for each log message matching the module.

Script Example
~~~~~~~~~~~~~~

Here is a sample script :code:`suricata.lua` processing log messages from Suricata, 
exported to syslog in Eve JSON format.

.. code:: lua

   local dirs = ntop.getDirs()
   package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
   require "lua_utils"
   local json = require ("dkjson")
   
   local syslog_module = {
      hooks = {},
   }
   
   -- The function below is called once to initialize the script
   function syslog_module.setup()
      return true
   end
   
   -- The function below is called for each log message received from Suricata
   function syslog_module.hooks.handleEvent(message)
      local alert = json.decode(message)
      tprint(alert)
   end 
   
   -- The function below is called once to terminate the script
   function syslog_module.teardown()
      return true
   end
   
   return syslog_module

