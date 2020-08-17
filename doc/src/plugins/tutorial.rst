.. _Plugin Tutorial:

Tutorial
========

In this tutorial a plugin which detects executable files :code:`.exe` requested over HTTP is created. This tutorial is step-by-step:

1. A basic plugin is created to print URLs containing :code:`.exe` to the command line is created
2. Created plugin is extended to create alerts and set a flow status

To create this plugin, `ntopng sources <https://github.com/ntop/ntopng>`_ are used. However, this is not a requirement. Plugins can be created also for packaged versions of ntopng. The directory which will contain plugin files is created under the ntopng plugins directory as

.. code:: bash

	# Launch this command from the root directory of the ntopng sources tree
	mkdir -p ./scripts/plugins/exes_download/


As this plugin detectes executable files :code:`.exe`, it must be run agains every HTTP flow. To run the plugin against every HTTP flow, a flow user script (see :ref:`Flow User Scripts`) must be placed under :code:`user_scripts/flows`:

.. code:: bash

	mkdir -p ./scripts/plugins/exes_download/user_scripts/flow/
	touch ./scripts/plugins/exes_download/user_scripts/flow/exes_download.lua

The file :code:`exes_download.lua` can then be edited as:

.. code:: lua

	local user_scripts = require("user_scripts")

	local script = {
	  -- Script category
	  category = user_scripts.script_categories.security,

	  -- This module is disabled by default
	  default_enabled = true,

	  -- See below
	  hooks = {},

	  -- Allow user script configuration from the GUI
	  gui = {
	    i18n_title = "EXEs Download",
	    i18n_description = "Detects .exe downloaded via HTTP",
	  }
	}

	-- #################################################################

	-- Defines an hook which is executed every time a procotol of a flow is detected
	function script.hooks.protocolDetected(now)
	   local http_info = flow.getHTTPInfo()

	   -- if the flow is HTTP and it contains a last_url...
	   if http_info and http_info["protos.http.last_url"] then
	      -- if an .exe is found in the URL...
	      if http_info["protos.http.last_url"]:match("%.exe") then
		 -- Prepare a text line to be printed to the console
		 local line = string.format("last_url: %s [%s]\n", http_info["protos.http.last_url"], shortFlowLabel(flow.getInfo()))
		 -- Actually print the line to the consol
		 io.write(line)
	      end
	   end
	end

	-- #################################################################

	return script

The first line

.. code:: lua

	local user_scripts = require("user_scripts")

Is necessary to specify a flow category in the :code:`script` table which must be returned at the end of the script. Indeed, the first key of this table is :code:`category` and has a value of :code:`user_scripts.script_categories.security`. Other categories are available in :code:`user_scripts.script_categories`. Failing to set a category would cause ntopng to choose a default category. The :code:`script` table then contains a boolean :code:`default_enabled = true` to make the user script enabled by default. This means ntopng will execute it and it will appear under the enabled flow user scripts in the web GUI. A table :code:`hooks = {}` is specified as well and is populated with :code:`function script.hooks.protocolDetected`. Finally a table :code:`gui` indicates a title and a description wich will be shown under the flow user scripts of the ntopng web GUI.

The function :code:`function script.hooks.protocolDetected` gets executed every time the Layer-7 application protocol of a flow is detected (see :ref:`Flow User Script Hooks`). This function accesses the API with :code:`flow.getHTTPInfo()` to get flow HTTP data. If the flow is not HTTP, this table will be :code:`nil`. If not :code:`nil`, the :code:`protos.http.last_url` of the flow is read and a :code:`:match` regexp is used to search for the string :code:`.exe` in the URL. If found, a simple line is prepared and printed to the console with :code:`io.write`. At this point, the plugin is functional. Restart ntopng and try to fetch a URL with a :code:`.exe`: this will cause ntopng to print flow details and URL to the console.

To extend this plugin to generate alerts and flow statuses, two additional directories need to be created, for :ref:`Flow Definitions` and :ref:`Alert Definitions`, respectively:

.. code:: bash

	mkdir -p ./scripts/plugins/exes_download/alert_definitions/
	mkdir -p ./scripts/plugins/exes_download/status_definitions/

Then, an alert definition and a flow status definition are created with two files:

.. code:: bash

	touch scripts/plugins/exes_download/status_definitions/status_exe_download.lua
	touch scripts/plugins/exes_download/alert_definitions/alert_exe_download.lua

Set the alert definition file :code:`alert_exe_download.lua` contents as:

.. code:: lua

	local alert_keys = require "alert_keys"

	-- #######################################################

	-- @brief Prepare an alert table used to generate the alert
	-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
	-- @param tls_info A Lua table with HTTP info gererated calling `flow.getHTTPInfo()`
	-- @return A table with the alert built
	local function createExeDownload(alert_severity, http_info)
	   local built = {
	      alert_severity = alert_severity,
	      alert_type_params = http_info -- This info will go into the alert JSON
	   }

	   return built
	end

	-- #######################################################

	return {
	   alert_key = alert_keys.user.alert_user_01,
	   -- equivalent
	   -- alert_key = {0, alert_keys.user.alert_user_01},
	   -- custom pens
	   -- alert_key = {312 -- PEN -- , 513 --alert id --]]},
	  i18n_title = "EXE download",
	  icon = "fas fa-exclamation",
	  creator = createExeDownload,
	}

The file contains the alert title and an icon which will be used by ntopng to print the alerts. As this is a user-developed plugin, and no other user-developed plugin is using it, key :code:`alert_keys.user.alert_user_01` is chosen as :code:`alert_key`. A :code:`createExeDownload` is implemented as well to add the detected HTTP information straight into the alert JSON.

Set the status definition file :code:`status_exe_download.lua` as:

.. code:: lua

	local alert_consts = require("alert_consts")
	local status_keys = require "flow_keys"

	return {
	  status_key = status_keys.user.status_user_01,
	  alert_severity = alert_consts.alert_severities.error,
	  alert_type = alert_consts.alert_types.alert_exe_download,
	  i18n_title = "EXE download",
	  i18n_description = "Flow has downloaded an executable file",
	}

The file contains a status title and a description which will be used by ntopng when showing the flow status. It also contains :code:`alert_severity` and :code:`alert_type` which tell ntopng the status is going to cause an alert of type :code:`alert_exe_download` to be triggered. As this is a user-developed plugin, and no other user-developed plugin is using it, key :code:`status_keys.user.status_user_01` is chosen as :code:`status_key`.

The final thing which is required to set the flow status and trigger the alert is to add an extra require to the user script

.. code:: lua

	local flow_consts = require("flow_consts")

And modify :code:`function script.hooks.protocolDetected(now)` as follow:

.. code:: lua

	-- Defines an hook which is executed every time a procotol of a flow is detected
	function script.hooks.protocolDetected(now)
	   local http_info = flow.getHTTPInfo()

	   -- if the flow is HTTP and it contains a last_url...
	   if http_info and http_info["protos.http.last_url"] then
	      -- if an .exe is found in the URL...
	      if http_info["protos.http.last_url"]:match("%.exe") then
		 flow.triggerStatus(
		    flow_consts.status_types.status_exe_download.create(
		       flow_consts.status_types.status_exe_download.alert_severity,
		       http_info
		    ),
		    100 --[[ flow_score --]],
		    100 --[[ cli_score ]],
		    10 --[[ srv_score]])
	      end
	   end
	end

Basically, a new function :code:`flow.triggerStatus` is added. This function wants the result of a call to :code:`create` as first parameter. Function :code:`create` takes a severity and an :code:`http_info` as first and second parameters, respectively. These two parameters are be passed to function :code:`createExeDownload` created in the alert definition file above. Then :code:`flow.triggerStatus` takes thress scores which are added to the flow, client and server scores, respectively.

Now the plugin is fully functional and ready to set flow statuses and trigger alerts when it detects and :code:`.exe` file. English strings can be localized as described in :ref:`Plugin Localization`.
