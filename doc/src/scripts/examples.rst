.. _Script Examples:

Examples
========

A couple of examples are presented to give the reader a quick and direct
overview of ntopng scripts.

.. _Flow Flooders:

Flow Flooders
-------------

Aim of this script is to trigger an alert when an host or a network is having more
than a predefined number of flows over a minute. As an host can be
either the client or the server of a flow, two types of alerts are meaningful in
this case, namely, a flow flood attacker alert and a flow flood victim
alert. The same reasoning can be applied to networks as well. A
network can either be considered a flow flood attacker or a flow flood
victim, depending on whether its host are the clients or servers of
the monitored flows. For the sake of this example, only flow flood victim alerts are considered for networks.

This script also exposes a threshold so that it can be configured from the :ref:`Web GUI`. The threshold is configurable on an host-by-host or CIDR basis. Indeed, a threshold which
is meaningful for an host is not necessarily meaningful for another host.

Full script sources are available on `GitHub flow flood script page
<https://github.com/ntop/ntopng/tree/dev/scripts/scripts/flow_flood>`_.

The complete structure of the script is as follows:

.. code:: bash

	  flow_flood/
	      |-- manifest.lua
	      |-- alert_definitions
	      |   `-- alert_flows_flood.lua
	      `-- checks
		  |-- host
		  |   |-- flow_flood_attacker.lua
		  |   `-- flow_flood_victim.lua
		  `-- network
		      `-- flow_flood_victim.lua


From the file system tree, it can be seen that the script is
self-contained in :code:`flow_flood`, a directory which carries a name
representative for the script. The :code:`manifest.lua` (see :ref:`Manifest`) script contains basic information and description:

.. code:: lua

   --
   -- (C) 2019-20 - ntop.org
   --

   return {
     title = "Flow Flood detector",
     description = "Detects flow flood attacks and triggers alerts",
     author = "ntop",
     dependencies = {},
   }

However, as this script generates alerts,
:code:`alert_flows_flood.lua` is needed under
:code:`alert_definitions` to tell ntopng about this.

The logic stays under :code:`checks`  (see :ref:`Checks`) which
has two sub-directories: :code:`host` and :code:`network`, each one
containing Lua files with the logic necessary to trigger the
alert. ntopng will execute scripts under the :code:`host` directory on
every host and scripts under the :code:`network` directory on every
network.

Let's have a closer look at :code:`host` s :code:flow_flood_attacker.lua`, of the
scripts executed on hosts (the other Lua script are similar):

.. code:: lua

   --
   -- (C) 2019-20 - ntop.org
   --

   local alerts_api = require("alerts_api")
   local alert_consts = require("alert_consts")
   local checks = require("checks")

   local script = {
     default_enabled = true,
     default_value = {
       -- "> 50"
       operator = "gt",
       threshold = 50,
     },

     -- This script is only for alerts generation
     is_alert = true,

     -- See below
     hooks = {},

     gui = {
       i18n_title = "entity_thresholds.flow_attacker_title",
       i18n_description = "entity_thresholds.flow_attacker_description",
       i18n_field_unit = checks.field_units.flow_sec,
       input_builder = "threshold_cross",
       field_max = 65535,
       field_min = 1,
       field_operator = "gt";
     }
   }

   -- #################################################################

   function script.hooks.min(params)
     local ff = host.getFlowFlood()
     local value = ff["hits.flow_flood_attacker"] or 0

     -- Check if the configured threshold is crossed by the value and possibly trigger an alert
     alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_flows_flood, value)
   end

   -- #################################################################

   return script

The first thing to observe is that the script has only one function
with a predefined name :code:`script.hooks.min` which is part of the :ref:`Check Hooks` table. This name tells
ntopng to call this function on every host, *every minute*. The body
of the function is fairly straightforward. It access a Lua table
:code:`host`, with several methods available to be called. This Lua
table contains references and methods that can be called on every host
of the system. As the aim of this script is to determine whether the
host is a flow flooder, method :code:`host.getFlowFlood()` is called
which contains flooding information. Then, a :code:`value` is read
from key :code:`hits.flow_flood_attacker` of the returned
table.

At this point, checking whether to trigger an alert or not, depending on
whether the :code:`value` is above the predefined threshold, is up to
the ntopng engine. From the perspective of this script, it suffices to
call method :code:`alerts_api.checkThresholdAlert`. The method takes
as input some params which falls outside the scope of this example,
along with the type of alert that needs to be generated, and the
actual :code:`value`. That is pretty much all. The ntopng engine will
evaluate :code:`value` and possibly trigger the alert.

Let's now have a closer look at the :code:`local script` table, which
basically contains all the necessary configuration, default values, and
information to properly render a configuration page on the :ref:`Web GUI`.

The table tells ntopng this script is enabled by default
(:code:`default_enabled = true`) and also specify the default
threshold values that should be used when no configuration has been
input from the web GUI (:code:`default_value`).

Then, a boolean flag
:code:`is_alert = true` is used to indicate the purpose of this user
script is to generate alerts.

An empty :code:`hooks` table is then
specified. This table is used by ntopng to determine when a certain
check needs do be called. Remember the function
:code:`script.hooks.min`? That actually adds the entry :code:`min` to
the :code:`hooks` table so this script will be executed every minute!

Finally, there is a :code:`gui` table to give ntopng instructions on
how to render the configuration page of this check. Basically, a
title, description and unit of measure are indicated, along with an
input builder and upper and lower bounds for the input. Input
builders, as it will be seen in the next section, are used by ntopng
to render the configuration of the check.

Log Network Traffic
-------------------

This example shows how to log the traffic of a `local network`_.

.. code:: bash

	  network_monitor/
	      |-- manifest.lua
	      `-- checks
		  `-- network
		      `-- traffic_log.lua

The main structure is very similar to the `Flow Flooders` example above
so it won't be discussed again. The core logic is contained into the
`traffic_log.lua` script which can be seen below:

.. code:: lua

   local checks = require("checks")
   require("lua_utils")

   local script = {
     -- This is a network related script
     category = checks.script_categories.network,

     -- This module is enabled by default
     default_enabled = true,

     -- No configuration needed
     default_value = {},

     -- Hooks are defined below
     hooks = {},

     -- No GUI defined
     gui = {},
   }

   -- #################################################################

   function script.hooks.min(info)
     print(string.format("[%s]: in=%u, out=%u, inner=%u",
       info.entity_info.network_key,
       bytesToSize(info.entity_info.ingress),
       bytesToSize(info.entity_info.egress),
       bytesToSize(info.entity_info.inner),
     ))
   end

   -- #################################################################

   return(checks)

The `script.hooks.min` hook is called by ntopng every minute for every
local network. It prints into the console the local network CIDR along
with the ingress, egress and inner traffic since startup.

All the network information is contained into the `info`
parameter. The most relevant fields are:

- :code:`granularity`: how often this script is called (60 for this example)
- :code:`alert_entity`: the alert entity, can be passed to the alerts API
  to trigger alerts
- :code:`entity_info`: information about the network, see below for details
- :code:`check_config`: the current configuration of this check

The current network status is available into the `info.entity_info` field.
Here are reported the most important fields:

.. code::

   network_key string fe80::3252:cbff:fe6c:9c1b/64
   inner number 0
   broadcast table
   broadcast.inner number 0
   broadcast.egress number 0
   broadcast.ingress number 0
   egress number 19661
   num_hosts number 5
   ingress number 0
   throughput_bps number 35.692886352539
   engaged_alerts number 0

In particular:

- :code:`network_key`: the local network CIDR
- :code:`inner`: inner traffic value of the network since startup
- :code:`ingress`: ingress traffic value of the network since startup
- :code:`egress`: egress traffic value of the network since startup
- :code:`broadcast`: a table which contains `inner`, `egress` and `ingress`
  counters values for the broadcast traffic
- :code:`num_hosts`: number of active hosts of the network
- :code:`throughput_bps`: the current cumulative througput of the traffic
  of the network.
- :code:`engaged_alerts`: the currently engaged alerts of the network

A straightforward modification to the above script is to retrieve the
last minute ingress/egress/inner bytes instead of the startup values.
This can be easily accomplished by using the `network_delta_val` function:

.. code:: lua

   local egress_delta_bytes = alerts_api.network_delta_val("egress_delta", info.granularity, info.entity_info.egress)

The `egress_delta` identifier is a unique key that ntopng uses to hold the
values in subsequent calls to the function. The current network id is automatically
retrieved by ntopng. The granularity parameter is needed to differentiate between different
granularities. The last parameter, `info.entity_info.egress`, specifies the current value.
ntopng calculates the delta between this value and the previous one, which is stored into
the `egress_delta_bytes` variable.

.. _`local network`: ../basic_concepts/hosts.html#local-hosts

SNMP Topology Changed
---------------------

The full script source is available at the `GitHub SNMP topology change page
<https://github.com/ntop/ntopng/tree/dev/scripts/scripts/snmp_topology_change>`_.
The script requires the ntopng Enterprise M license in order to be run.

The complete structure of the script is as follows:

.. code:: bash

	  snmp_topology_change/
	      |-- manifest.lua
	      |-- alert_definitions
	      |	  `-- alert_snmp_topology_changed.lua
	      `-- checks
		  `-- snmp_device
		      `-- lldp_topology_changed.lua

This script uses the `LLDP <https://en.wikipedia.org/wiki/Link_Layer_Discovery_Protocol>`_
information that ntopng has collected to determine changes in the SNMP network topology.
When a new link is added or an old link is removed, the `alert_snmp_topology_changed` alert is generated.

Here is an analysis of the check reponsible for the alert generation.

.. code:: lua

   local script = {
      category = checks.script_categories.network,

      hooks = {},

      default_enabled = false,

      gui = {
	 i18n_title = "snmp.lldp_topology_changed_title",
	 i18n_description = "snmp.lldp_topology_changed_description",
      },
   }

   -- #################################################################

   function script.setup()
      return(ntop.isEnterpriseM())
   end

   -- #################################################################

   local function storeTopologyChangedAlert(info, arc, nodes, subtype)
      local parts = split(arc, "@")

      if(#parts == 2) then
	 alerts_api.store(
	    info.alert_entity, {
	       alert_type = alert_consts.alert_types.alert_snmp_topology_changed,
	       alert_subtype = subtype,
	       alert_severity = alert_consts.alert_severities.warning,
	       alert_granularity = info.granularity,
	       alert_type_params = {
		  node1 = parts[1], ip1 = nodes[parts[1]],
		  node2 = parts[2], ip2 = nodes[parts[2]],
	       },
	 })
      end
   end

   -- #################################################################

   function script.hooks.snmpDevice(device_ip, info)
      local arcs_key = "ntopng.cache.snmp_topology_arcs_monitor." .. device_ip
      local old_arcs = ntop.getPref(arcs_key)

      if not isEmptyString(old_arcs) then
	 old_arcs = json.decode(old_arcs) or {}
      else
	 old_arcs = {}
      end

      local nodes, arcs = snmp_utils.snmp_load_devices_topology(device_ip)
      local is_first_run = table.empty(old_arcs)
      local new_arcs = {}

      for arc in pairs(arcs) do
	 if(not is_first_run) then
	    if(not old_arcs[arc]) then
	       storeTopologyChangedAlert(info, arc, nodes, "arc_added")
	    else
	       old_arcs[arc] = nil
	    end
	 end

	 new_arcs[arc] = true
      end

      for arc in pairs(old_arcs) do
	 storeTopologyChangedAlert(info, arc, nodes, "arc_removed")
      end

      ntop.setPref(arcs_key, json.encode(new_arcs))
   end

   -- ################################################################

   return script

Here is a description of the general structure:

- :code:`script.category` the category for this script is `network`
- :code:`script.default_enabled` the script is disabled by default
- :code:`script.gui` defines the essential metadata, necessary to print the configuration into the GUI
- :code:`script.setup`: this returns false if the Enterprise M edition is not available, disabling the script
- :code:`script.hooks.snmpDevice`: defines the hook to be called after ntopng has processed a specific SNMP device.
  The `device_ip` contains the IP address of the SNMP device, whereas the `info` field contains some computed information
  on the device (use `tprint(info)` to get a list of fields). See below for a detailed description of this example.
- :code:`storeTopologyChangedAlert`: this function is responsible for the alert triggering part.

The `script.hooks.snmpDevice` function uses the `snmp_utils.snmp_load_devices_topology` function to retrieve the
latest LLDP information for the current SNMP device. The function returns a list of nodes and arcs involved
in this particular SNMP device topology. The `nodes` are Lua tables which maps `node_name` -> `node_ip`, for example:

.. code:: lua

    table
   AccessSW-1 string 172.16.24.1
   NetworkSpine-2 string 172.16.23.1

The `arcs` are Lua tables which contains links information between the SNMP device and other devices. Here is an example:

.. code:: lua

    table
   AccessSW-1@NetworkSpine-2 table
   AccessSW-1@NetworkSpine-2.1 number 25151496709
   AccessSW-1@NetworkSpine-2.2 string 2111493

The above information can be interpreted as:

- Exists a link between `AccessSW-1` and `NetworkSpine-2`
- `AccessSW-1` is connected to `NetworkSpine-2` via the interface with index `2111493`
- The total traffic registered from `AccessSW-1` to `NetworkSpine-2` is 25151496709 bytes

The check keeps track of the old arcs by storing them into the Redis key `ntopng.cache.snmp_topology_arcs_monitor.<device_ip>`.
By comparing the old registered arcs with the new ones it can determine if an arc was removed or added.
