Examples
========

How to properly code a plugin is described in the reminder of this
section. However, before delving into the technical details, a couple
of examples are presented to give the reader a quick and direct
overview of ntopng plugins.

Blacklisted Flows
-----------------

Aim of this plugin is to trigger an alert every time a flow is found
to have its client or server (or both) in a blacklist. ntopng loads 
custom and predefined blacklists as explained in :ref:`Category
Lists`. This plugin tests each flow to test client and server, and
possibly create an alert when they are found to be blacklisted. ntopng
looks at certain plugin properties to know it has to execute the plugin
for every flow it sees.

Full plugin sources are available on `GitHub
<https://github.com/ntop/ntopng/tree/dev/scripts/plugins/blacklisted>`_.

The complete structure of the plugin is as follows

.. code:: bash

	  blacklisted
	      |-- plugin.lua
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
sub-directories and a :code:`plugin.lua` file, a sort of plugin
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
the actual business logic stays in directory :code:`user_scripts`.

As this plugin requires flows to carry on its task, directory :code:`user_scripts` with the
business logic must contain a subdirectly :code:`flow`, which, in
turn, contains file :code:`blacklisted.lua`. ntopng knows it has to
execute :code:`blacklisted.lua` agains each flow it sees because
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
method returns true, a couple of scores are computed. Scores are
numbers associated to the client and server of the flow and attempt to
summarize how critical is the issue for both the client and the
server.

So why the client score is much higher when the server is blacklisted?
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

   
Hosts Traffic
-------------
