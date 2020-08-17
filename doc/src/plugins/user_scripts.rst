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

  local user_scripts = require("user_scripts")

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
  - :code:`local_only` (optional, hosts only): if true, the user script is only executed for local hosts.
  - :code:`packet_interface_only` (optional): only execute the script on packet interfaces, excluding ZMQ interfaces.
  - :code:`l4_proto` (optional, flows only): only execute the script for flows matching the L4 protocol.
  - :code:`l7_proto` (optional, flows only): only execute the script for flows matching the L7 application protocol.
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

Flow user scripts are executed on each network flow. The user script have access to flow information such as L4 and L7 protocols, peers involved in the communication, and other things.
This information can be retrieved via the `Flow User Scripts API`_.

Refer to :ref:`Flow User Script Hooks` for available hooks.

.. _`Flow User Scripts API`: ../api/lua_c/flow_user_scripts/index.html

.. _Setting Flow Statuses:

Setting Flow Statuses
~~~~~~~~~~~~~~~~~~~~~

Flow statuses are set with

.. code:: lua

  flow.setStatus(flow_status_type, flow_score, cli_score, srv_score)


See `flow.lua <https://github.com/ntop/ntopng/blob/dev/scripts/callbacks/interface/flow.lua>`_ for the source code. Parameters are:

- :code:`flow_status_type`: flow status as described in :ref:`Flow Definitions`.
- :code:`flow_score`: A score to be assigned to the current flow
- :code:`cli_score`: A score to be added to the score of the flow client
- :code:`srv_score`: A score to be added to the score to the flow server

Setting a flow status will cause ntopng to show it across the interface.

.. _Triggering Flow Alerts:

Triggering Flow Alerts
~~~~~~~~~~~~~~~~~~~~~~

A status can also determine the triggering of an alert. Triggering an alert is done calling

.. code:: lua

  flow.triggerStatus(flow_status_type, status_info, flow_score, cli_score, srv_score, custom_severity)

See `flow.lua <https://github.com/ntop/ntopng/blob/dev/scripts/callbacks/interface/flow.lua>`_ for the source code. Parameters are those described in :ref:`Setting Flow Statuses` plus a :code:`custom_severity`.

.. _Other User Scripts:

Other User Scripts
------------------

ntopng supports users scripts for the following traffic elements:

  - :code:`interface`: a network interface of ntopng. Check out the `Interface User Scripts API`_.
  - :code:`network`: a local network of ntopng. Check out the `Network User Scripts API`_.
  - :code:`host`: a local/remote host of ntopng. Check out the `Host User Scripts API`_.
  - :code:`system`: the system on top of which is running ntopng
  - :code:`SNMP interfaces`: interfaces of monitored SNMP devices

Refer to :ref:`Other User Script Hooks` for available hooks.

.. _`Interface User Scripts API`: ../api/lua_c/interface_user_scripts/index.html
.. _`Network User Scripts API`: ../api/lua_c/network_user_scripts/index.html
.. _`Host User Scripts API`: ../api/lua_c/host_user_scripts/index.html

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

.. _Triggering Alerts:

Triggering Alerts
-----------------

An user script can trigger an alert when some anomalous behavior is
detected. Users can use the already provided hook callbacks:

  - :code:`alerts_api.threshold_check_function`: can check thresholds
    and trigger threshold cross alerts
  - :code:`alerts_api.anomaly_check_function`: checks anomaly status,
    set by the C core

or build their own alert custom logic. In the latter case, the hook
callback should call the following functions:

  - :code:`alerts_api.trigger(entity_info, type_info)` whenever the
    entity state is alerted
  - :code:`alerts_api.release(entity_info, type_info)` whenever the
    entity state is not alerted

Alert state is kept internally so multiple trigger/releases of the
same alert have no effect.  The :code:`type_info` is specific of the
alert_type and should be built using one of the "type_info building
functions" available into :code:`alerts_api.lua`, for example
:code:`alerts_api.thresholdCrossType`.


Built-in Alerts
~~~~~~~~~~~~~~~

Alert types are defined into :code:`alert_consts.alert_types` inside
:code:`scripts/lua/modules/alert_consts.lua`. Additional alert types
can be created as explained in :ref:`Alert Definitions`.
