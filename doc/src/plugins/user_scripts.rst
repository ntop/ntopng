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


Every user script must return a :code:`script` with the following keys:

  - :code:`hooks` (mandatory): a map :code:`hook -> callback`
    which defines on which :code:`hook` the :code:`callback` is called. User scripts must register to at least one hook. The list of available hooks depends on the script type. :ref:`Flow User Scripts` hooks 	are different from :ref:`Other User Scripts` hooks.
  - :code:`gui` (optional): See :ref:`Web UI` for additional details
  - :code:`local_only` (optional, hosts only): if true, the user script
    is only executed for local hosts.
  - :code:`packet_interface_only` (optional): only execute the script
    on packet interfaces, excluding ZMQ interfaces.
  - :code:`l4_proto` (optional, flows only): only execute the script
    for flows matching the L4 protocol.
  - :code:`l7_proto` (optional, flows only): only execute the script
    for flows matching the L7 application protocol.
  - :code:`nedge_only` (optional): if true, the script is only
    executed in nEdge
  - :code:`nedge_exclude` (optional): if true, the script is not
    executed in nEdge
  - :code:`default_value` (optional): the default value for the script
    configuration, in the form :code:`<script_key>;<operator>;<value>`
    (e.g. :code:`syn_flood_victim;gt;50`)
  - :code:`default_enabled` (optional): if false, the script is
    disabled by default

Furthermore, a script may define the following extra callbacks, which
are only called once per script:

  - :code:`setup()`: called once per user
    script. If it returns :code:`false` then the script is considered
    disabled and its hooks are not be called.
  - :code:`teardown()`: called after the script
    operation is complete (e.g. after all the hosts have been iterated
    and hooks called).

.. _Hooks:

Hooks
-----

ntopng uses hooks to know when a certain user script needs to be executed. Hooks are string keys of the plugin :code:`hooks` table and have a :code:`callback` function assigned. Strings identify:

- Predefined events for flows
- Intervals of time for any other network element such as an host, or a network

So for example a user script which needs to be called every minute will implement a function
and assign it to hook :code:`min`. Similarly, a user script which needs to be called every time a flow goes idle, will implement a function and assign it to hook :code:`flowEnd`.

:code:`all` is a special hook name which will cause the associated callback to be called for all the events.

A callback function has the following form:

.. code:: lua

  function my_callback(params)
    -- ...
  end

The information contained into the params table depends on the script type:

  - :code:`granularity` (traffic element only): the current granularity
  - :code:`alert_entity` (traffic element only): the traffic element entity type
  - :code:`entity_info` (traffic element only): contains entity specific data (e.g. on hosts, it is the output of :code:`Host:lua()`)

It is the ntopng engine which takes care of calling the hook callback function
with table :code:`params` opportunely populated.

Hooks and user scripts are described in detail for flows and other
network elements in the reminder of this section.


.. _Flow User Scripts:

Flow User Scripts
-----------------

Flow user scripts are executed on each network flow. The user script have access to flow information such as L4 and L7 protocols, peers involved in the communication, and other things.

Available hooks for flow user scripts are the following:

  - :code:`protocolDetected`: called after the Layer-7 application protocol has been detected
  - :code:`statusChanged`: called when the internal status of the flow has changed since the previous invocation. The flow status can be used to detect anomalous behaviors.
  - :code:`periodicUpdate`: called every few minutes on long-lived flows
  - :code:`flowEnd`: called when the flow is considered finished


.. _Other User Scripts:

Other User Scripts
------------------

ntopng supports users scripts for the following traffic elements:

  - :code:`interface`: a network interface of ntopng
  - :code:`network`: a local network of ntopng
  - :code:`host`: a local/remote host of ntopng
  - :code:`system`: the system on top of which is running ntopng
  - :code:`SNMP interfaces`: interfaces of monitored SNMP devices

Traffic element scripts are called periodically. Available hooks are the following:

  - :code:`min`: called every minute
  - :code:`5mins`: called every 5 minutes
  - :code:`hour`: called every hour
  - :code:`day`: called every day (at midnight)


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
