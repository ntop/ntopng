User Scripts
============

User scripts are the core of plugins. They actually allow certain
actions to be performed periodically, or when a certain event
occurs. The logic of a plugin is contained in its users
scripts. A plugin can contain many user scripts. Differences between a
plugin and a user script are described in :ref:`Plugins vs User Scripts`.

Hooks
-----

How does ntopng know when to call a certain user script? By means of
hooks. Hooks are pre-defined events (for flows) of intervals of time
(for any other network element such as an host, or a network) which
can be associated to functions to be called. Such functions are also
referred to as :code:`callbacks`. So for example if a user
script needs to be called every minute, it will implement a function
assigned to hook :code:`min`. Similarly, if a user script needs to be
called every time a flow goes idle, it will implement a function
assigned to hook :code:`flowEnd`.

Hooks and user scripts are described in detail for flows and other
network elements in the reminder of this section.

Structure
---------

Here is the skeleton for a generic user script:

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


Every user script must return a :code:`script` table which exposes the
following attributes:

  - :code:`hooks` (mandatory): a map :code:`hook_name -> callback`
    which defines on which events the callback should be called. The
    scripts must register to at least one hook. The list of available
    hooks depends on the script type. :ref:`Flow User Scripts` hooks
    are different from :ref:`Other User Scripts` hooks.
  - :code:`gui` (optional): See :ref:`Web UI` for additional details
  - :code:`local_only` (optional, hosts only): if true, the script
    will not be executed on remote hosts
  - :code:`packet_interface_only` (optional): only execute the script
    on packet interfaces
  - :code:`l4_proto` (optional, flows only): only execute the script
    for flows matching the L4 proto
  - :code:`l7_proto` (optional, flows only): only execute the script
    for flows matching the L7 proto see 2nd column in
    lua_utils.lua::l4_keys for supported protocols.
  - :code:`nedge_only` (optional): if true, the script will only be
    executed in nEdge
  - :code:`nedge_exclude` (optional): if true, the script will not be
    executed in nEdge
  - :code:`default_value` (optional): the default value for the script
    configuration, in the form :code:`<script_key>;<operator>;<value>`
    (e.g. :code:`syn_flood_victim;gt;50`)
  - :code:`default_enabled` (optional): if false, the script will be
    disabled by default

.. note::

     :code:`all` is a special hook name which will cause the
           associated callback to be called for all the events.

Futhermore, a script may define the following extra callbacks, which
are only called once per script:

  - :code:`setup()`: a function which will be called once per user
    script. If it returns :code:`false` then the script is considered
    disabled and its hooks will not be called.
  - :code:`teardown()`: a function to be called after the script
    operation is complete (e.g. after all the hosts have been iterated
    and hooks called).

Hook Callbacks
--------------

An hook callback function takes the following form:

.. code:: lua

  function my_callback(params)
    -- ...
  end

The information contained into the params object depends on the script type:

  - :code:`granularity` (traffic element only): the current granularity
  - :code:`alert_entity` (traffic element only): the traffic element entity type
  - :code:`entity_info` (traffic element only): contains entity specific data
    (e.g. on hosts, it is the output of :code:`Host:lua()`)

It is the ntopng engine which takes care of calling the hook callback
with table :code:`params` opportunely populated.

.. _Flow User Scripts:

Flow User Scripts
-----------------

Flow user scripts are executed on each network flow. The user can
inspect the flow protocol, peers involved in the communication, and
other specific information.

A user script can hook to the following functions:

  - `protocolDetected`: called after the Layer-7 application protocol
    has been detected
  - `statusChanged`: called when the internal status of the flow has
    changed since the previous invocation. The flow status can be used
    to detect anomalous behaviours.
  - `periodicUpdate`: called every few minutes on long-lived flows
  - `flowEnd`: called when the flow is considered finished

See the `Flow API`_ for a documentation of the available functions
which can be called inside a flow user script.

.. _`Flow API`: ../lua_c/flow/index.html

.. _Other User Scripts:

Other User Scripts
------------------

ntopng supports users scripts on the following traffic elements:

  - :code:`interface`: a network interface of ntopng
  - :code:`network`: a local network of ntopng
  - :code:`host`: a local/remote host of ntopng
  - :code:`system`: the system on top of which is running ntopng
  - :code:`SNMP interfaces`: interfaces of monitored SNMP devices

Hooks
~~~~~

Traffic element scripts are called periodically. The corresponding available hooks are:

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

   
Triggering Alerts
-----------------

An user script can trigger an alert when some anomalous behaviour is
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

Alerts state is kept internally so multiple trigger/releases of the
same alert have no effect.  The :code:`type_info` is specific of the
alert_type and should be built using one of the "type_info building
functions" available into :code:`alerts_api.lua`, for example
:code:`alerts_api.thresholdCrossType`.


Built-in Alerts
~~~~~~~~~~~~~~~

Alert types are defined into :code:`alert_consts.alert_types` inside
:code:`scripts/lua/modules/alert_consts.lua`. Additional alert types
can be created as explained in :ref:`Alert Definitions`.
