.. _Plugin Examples:

Examples
========

How to properly code a plugin is described in the reminder of this
section. However, before delving into the technical details, a couple
of examples are presented to give the reader a quick and direct
overview of ntopng plugins.

.. _Blacklisted Flows:

Blacklisted Flows
-----------------

Aim of this plugin is to trigger an alert every time a flow is found
to have its client or server (or both) in a blacklist. ntopng loads
custom and predefined blacklists as explained in :ref:`Category
Lists`. This plugin tests each flow for its client and server, and
possibly create an alert when they are found to be blacklisted.

Full plugin sources are available on `GitHub blacklisted flows plugin
page
<https://github.com/ntop/ntopng/tree/dev/scripts/plugins/blacklisted>`_.

The complete structure of the plugin is as follows:

.. code:: bash

	  blacklisted
	      |-- manifest.lua
	      |-- user_scripts
		  `-- flow
		      `-- blacklisted.lua
	      |-- alert_definitions
		  `-- alert_flow_blacklisted.lua
	      |-- status_definitions
		  `-- status_blacklisted.lua

As it can be seen from the file system tree, a plugin is a set of Lua
files, placed in pre-defined sub-directories.

The root directory, :code:`blacklisted`, should carry a name which is
representative for the plugin. This directory contains other
sub-directories and a :code:`manifest.lua` file, a plugin
manifest containing basic plugin information:

.. code:: lua

	  --
	  -- (C) 2019-20 - ntop.org
	  --

	  return {
	     title = "Blacklisted Hosts",
	     description = "Detects blacklisted hosts and triggers alerts",
	     author = "ntop",
	     version = 1,
	     dependencies = {},
	  }

Sub-directories
:code:`alert_definitions` and :code:`status_definitions` contain Lua
scripts which are necessary to tell ntopng the plugin is going to set certain flow status
and trigger certain alerts.

In this specific plugin,
:code:`alert_flow_blacklisted.lua` tells ntopng the plugin is willing
to create an alert for blacklisted flows. Similarly,
:code:`status_blacklisted.lua` tells ntopng the plugin is going to set
a blacklisted status for certain flows. Those two directories, as said
by their names, contain just definitions of alerts and flow status,
the actual logic stays in directory :code:`user_scripts`.

As this plugin requires flows to carry on its task, directory
:code:`user_scripts` with the logic must contain a subdirectly
:code:`flow`, which, in turn, contains file
:code:`blacklisted.lua`. ntopng knows it has to execute
:code:`blacklisted.lua` agains each flow it sees because
:code:`blacklisted.lua` is found under the :code:`flow` directory.

Let's have a look at the
contents of :code:`blacklisted.lua`:

.. code:: lua

   --
   -- (C) 2019-20 - ntop.org
   --

   local flow_consts = require("flow_consts")

   -- #################################################################

   local script = {
      -- NOTE: hooks defined below
      hooks = {},

      gui = {
	 i18n_title = "flow_callbacks_config.blacklisted",
	 i18n_description = "flow_callbacks_config.blacklisted_description",
      }
   }

   -- #################################################################

   function script.hooks.protocolDetected(now)
      if flow.isBlacklisted() then
	 local info = flow.getBlacklistedInfo()
	 local flow_score = 100
	 local cli_score, srv_score

	 if info["blacklisted.srv"] then
	    cli_score = 100
	    srv_score = 5
	 else
	    cli_score = 5
	    srv_score = 10
	 end

	 flow.triggerStatus(flow_consts.status_types.status_blacklisted.status_id, info,
	    flow_score, cli_score, srv_score)
      end
   end

   -- #################################################################

   return script


The first thing to observe, is that :code:`blacklisted.lua` contains a
single :code:`function` with a predefined
name :code:`script.hooks.protocolDetected`. This name tells
ntopng to execute the plugin for every flow, as soon as the flow has
its :code:`protocolDetected`, which is one of the several events
plugins can attach to.

The body of the function has access to a :code:`flow` Lua table, with
several methods available to be called, among which
:code:`flow.isBlacklisted()`. Method :code:`flow.isBlacklisted()`
returns a boolean which is either true or false, depending on whether
any of the client or server is blacklisted. As this plugin wants to
trigger an alert then the flow is blacklisted, method is called and
tested in the first :code:`if`. When the flow is blacklisted and the
method returns true, a couple of scores are computed. **Scores** are
numbers associated to the client and server of the flow and attempt to
summarize how critical is the issue for both the client and the
server.

So why does the client score is much higher when the server is blacklisted?
Because in this case it is assumed that the client is infected and
attempting to contact malicious hosts. When is the client to be
blacklisted, then it may just be a scan attempt by a malicious host
and thus the score is lower.

Once the scores have been computed, the function calls
:code:`flow.triggerStatus`. This is the actual call that causes
ntopng to set the blacklisted status and trigger an alert! This call
wants the two scores as parameters, along with the flow status defined
in :code:`status_definitions` and an info table which contains certain
extra details and description of the flow blacklisted peers.

From this point on, the flow will appear as alerted and with status
blacklisted in the ntopng web UI, along with the scores specified for
its client and server. That is pretty much all to create a flow script!

A quick note on the :code:`gui` section. It has just a title and a
description that will be used by ntopng in the web UI, to allow a user
to enable/disable the plugin.

.. _Flow Flooders:

Flow Flooders
-------------

Aim of this plugin is to trigger an alert when an host or a network is having more
than a predefined number of flows over a minute. As an host can be
either the client or the server of a flow, two types of alerts are meaningful in
this case, namely, a flow flood attacker alert and a flow flood victim
alert. The same reasoning can be applied to networks as well. A
network can either be considered a flow flood attacker or a flow flood
victim, depending on whether its host are the clients or servers of
the monitored flows.

The predefined threshold can be configured from the web UI so that one
can tune it on a host-by-host or CIDR basis. Indeed, a threshold which
is meaningful for an host is not necessarily meaningful for another host.

Full plugin sources are available on `GitHub flow flood plugin page
<https://github.com/ntop/ntopng/tree/dev/scripts/plugins/flow_flood>`_.

The complete structure of the plugin is as follows:

.. code:: bash

	  flow_flood/
	      |-- manifest.lua
	      |-- alert_definitions
	      |   `-- alert_flows_flood.lua
	      `-- user_scripts
		  |-- host
		  |   |-- flow_flood_attacker.lua
		  |   `-- flow_flood_victim.lua
		  `-- network
		      `-- flow_flood_victim.lua


From the file system tree, it can be seen that the plugin is
self-contained in :code:`flow_flood`, a directory which carries a name
representative for the plugin. The :code:`manifest.lua` script, a sort
of manifest for the plugin, contains basic information and description

.. code:: lua

   --
   -- (C) 2019-20 - ntop.org
   --

   return {
     title = "Flow Flood detector",
     description = "Detects flow flood attacks and triggers alerts",
     author = "ntop",
     version = 1,
     dependencies = {},
   }

This plugin doesn't work on flows, so no :code:`flow` directory is
present under :code:`user_scripts` and no :code:`status_definitions`
is necessary as it has been seen for the `Blacklisted
Flows`_. However, as this plugin generates alerts,
:code:`alert_flows_flood.lua` is needed under
:code:`alert_definitions` to tell ntopng about this.

The logic stays under :code:`user_scripts` which
has two sub-directories: :code:`host` and :code:`network`, each one
containing lua files with the logic necessary to trigger the
alert. ntopng will execute scripts under the :code:`host` directory on
every host and scripts under the :code:`network` directory on every
network.

Let's have a closer look at :code:`host` s :code:`flow_flood_attacker.lua`, of the
scripts executed on hosts (the other Lua script are similar):

.. code:: lua

   --
   -- (C) 2019-20 - ntop.org
   --

   local alerts_api = require("alerts_api")
   local alert_consts = require("alert_consts")
   local user_scripts = require("user_scripts")

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
       i18n_field_unit = user_scripts.field_units.flow_sec,
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
with a pre-defined name :code:`script.hooks.min`. This name tells
ntopng to call this function on every host, *every minute*. The body
of the function is fairly straightforward. It access a Lua table
:code:`host`, with several methods available to be called. This Lua
table contains references and methods that can be called on every host
of the system. As the aim of this plugin is to determine whether the
host is a flow flooder, method :code:`host.getFlowFlood()` is called
which contains flooding information. Then, a :code:`value` is read
from key :code:`hits.flow_flood_attacker` of the returned
table.

At this point, checking whether to trigger an alert or not, depending on
whether the :code:`value` is above the pre-defined threshold, is up to
the ntopng engine. From the perspective of this script, it suffices to
call method :code:`alerts_api.checkThresholdAlert`. The method takes
as input some params which falls outside the scope of this example,
along with the type of alert that needs to be generated, and the
actual :code:`value`. That is pretty much all. The ntopng engine will
evaluate :code:`value` and possibly trigger the alert.


Let's now have a closer look at the :code:`local script` table, which
basically contains all the necessary configuraton, default values, and
information to properly render a configuration page on the web UI.

The table tells ntopng this script is enabled by default
(:code:`default_enabled = true`) and also specify the default
threshold values that should be used when no configuration has been
input from the web UI (:code:`default_value`).

Then, a boolean flag
:code:`is_alert = true` is used to indicate the purpose of this user
script is to generate alerts.

An empty :code:`hooks` table is then
specified. This table is used by ntopng to determine when a certain
user script needs do be called. Remember the function
:code:`script.hooks.min`? That actually adds the entry :code:`min` to
the :code:`hooks` table so this plugin will be exected every minute!

Finally, there is a :code:`gui` table to give ntopng instructions on
how to render the configuration page of this user script. Basically, a
title, description and unit of measure are indicated, along with an
input builder and upper and lower bounds for the input. Input
builders, as it will be seen in the next section, are used by ntopng
to render the configuration of the user script.


