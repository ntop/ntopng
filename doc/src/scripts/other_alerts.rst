.. _OtherAlerts target:

Other Alerts (Interface, MAC, Local Networks, SNMP, System, User)
#################################################################

All these families of alerts can be created in the same exact way, with no difference except for a couples that will be shown in details later.

ntopng supports users scripts (Lua) for the following traffic elements:

  - :code:`interface`: a network interface of ntopng. Check out the `Interface Checks API`_.
  - :code:`network`: a local network of ntopng. Check out the `Network Checks API`_.
  - :code:`system`: the system on top of which is running ntopng.
  - :code:`SNMP interfaces`: interfaces of monitored SNMP devices.
  - :code:`mac`: a MAC address of ntopng.


Refer to :ref:`Check Hooks` for available hooks.

.. _`Interface Checks API`: ../api/lua_c/interface_checks/index.html
.. _`Network Checks API`: ../api/lua_c/network_checks/index.html


Create the check
================
First of all create the check.

To do that, create a new file in the :code:`scripts/lua/modules/check_definitions` folder; note that 
in this folder various folders are present, one per alert family type.

For example if a local network alert needs to be created, just add a new file in the :code:`scripts/lua/modules/check_definitions/network` folder.

Handles the default conf and GUI part
=====================================
In the newly example_check.lua created file, add the following section:

.. code:: lua

	local checks = require("checks")
	local other_alert_keys = require "other_alert_keys"
	local alert_consts = require("alert_consts")

	local check_example = {
		-- Describe the script category
		category = checks.check_categories.network,
		-- Describe the script severity
		severity = alert_consts.get_printable_severities().warning,

		-- Is the alert enabled or not by default?
		default_enabled = false,
		-- The alert ID
		alert_id = other_alert_keys.other_alert_example,

		-- Is some kind of threshold / user input needed?
		default_value = {
			operator = "gt",
			threashold = 128,
		},
		
		-- Handles the GUI (visualization) part
		gui = {
			i18n_title = "alerts_dashboard.check_example_title",
			i18n_description = "alerts_dashboard.check_example_description",
			i18n_field_unit = checks.field_units.http_flow,
			input_builder = "threshold_cross",
			field_max = 65535,
			field_min = 1,
			field_operator = "gt";
		}
	}

	return check_example


- :code:`category`: Here add the category of the alert, for instance :code:`network` (a list of the available categories can be found in scripts/lua/modules/alert_categories.lua);
- :code:`severity`: Describe the severity of an alert (list of available severities in scripts/lua/modules/alert_severities.lua);
- :code:`default_enabled`: A boolean representing if a check needs to be enabled by default (without the user enabling it) or not;
- :code:`alert_id`: Represent the Alert ID corresponding to this check (see the following section);
- :code:`default_value`: Is there a need for the user to configure something (e.g. a threshold, a list of nations)? if not, simply put :code:`default_value = {}`;
- :code:`hooks`: a Lua table with hook names as key and checks as values. :ref:`Check Hooks` are events or points in time. ntopng uses hooks to know when to call a check. A check defining a hook will get the hook callaback called by ntopng. Checks must register to at least one hook. See :ref:`Check Hooks`.
- :code:`gui`: This section handles the GUI part, so the check description, the name, ecc.:
	
	- :code:`i18n_title`: Title (Name) of the check;
	- :code:`i18n_description`: Description (Why/When it triggers the alert) of the check;
	- :code:`i18n_field_unit`: ONLY IF :code:`default_value` IS NOT EMPTY, the type of threshold, is it a bit/s or a score/s? (see: scripts/lua/modules/field_units.lua);
	- :code:`input_builder`: ONLY IF :code:`default_value` IS NOT EMPTY, what kind of input the user needs? a threashold_cross or an items_list?;
	- :code:`field_max`: max value for the threshold field
	- :code:`field_min`: min value for the threshold field
	- :code:`field_step`: step value for the threshold field
	- :code:`field_operator`: can be used to fix a specific threshold operator: :code:`gt`
	for the ">" operator, :code:`lt` for the "<" operator
	- :code:`i18n_field_unit`: localization string to be displayed after the threshold
  	field (e.g. "Bytes" in the example above). `checks.field_units` provides some commonly used values.


Other non mandatory options:
  - :code:`packet_interface_only` (optional): only execute the script on packet interfaces, excluding ZMQ interfaces.
  - :code:`nedge_only` (optional): if true, the script is only executed in nEdge.
  - :code:`nedge_exclude` (optional): if true, the script is not executed in nEdge.


Trigger the alert
=================

To be able to trigger the alert of the example_check, a callback function that handles when to trigger the alert is needed;
The check can be executed with 3 different periodicity:

- :code:`min`: Called every minute.
- :code:`5mins`: Called every 5 minutes.
- :code:`hour`: Called every hour.
- :code:`day`: Called every day (at midnight localtime).
- :code:`all`: A special hook name which will cause the associated check to be called for all the available hooks.


Add to the lua the callback function to be run that checks to trigger or not the alert and then add the callback to the
check_example table

.. code:: lua

	local function check_to_trigger_allert(params)
		-- Get the configured threhsold by the user in the GUI
		local user_configured_threshold = params.check_config.threshold
		-- Example of value to check
		local my_value_to_check = 10

		-- Create the alert instance, this needs alwais to be done
		local alert = alert_consts.alert_types.alert_my_example_alert.new(
			my_value_to_check,
			threshold
		)
	
		-- These two functions call automatically add various info to the alert
		-- MUST BE CALLED
		alert:set_info(params)
		alert:set_subtype(script.key)
		
		-- Trigger the alert, if the threhsold was exceeded
		if my_value_to_check > user_configured_threshold then
			alert:trigger(params.alert_entity, nil, params.cur_alerts)
		else
		-- Do not trigger the alert, the threshold was not exceeded
			alert:release(params.alert_entity, nil, params.cur_alerts)
		end
	end
	-- Remember to add the right periodicity to the callback
	script.hooks["min"] = check_to_trigger_allert



Handle Custom Changes on Various Situations 
===========================================

There are some useful callbacks executed at specific times that can be used to do
various checks/controls

.. code:: lua

	-- #################################################################

	function script.onEnable(hook, hook_config)
		ntop.setPref("ntopng.prefs.is_broadcast_domain_too_large_enabled", 1)
	end

	-- #################################################################

	function script.onDisable(hook, hook_config)
		ntop.setPref("ntopng.prefs.is_broadcast_domain_too_large_enabled", 0)
	end

	-- #################################################################

	function script.onLoad(hook, hook_config)
		ntop.setPref("ntopng.prefs.is_broadcast_domain_too_large_enabled", 1)
	end

	-- #################################################################

	function script.onUnload(hook, hook_config)
		ntop.setPref("ntopng.prefs.is_broadcast_domain_too_large_enabled", 0)
	end

	-- #################################################################

	function script.setup()
		return ntop.getPref("ntopng.prefs.is_broadcast_domain_too_large_enabled") == "1"
	end

	-- #################################################################

	function script.teardown()
		ntop.setPref("ntopng.prefs.is_broadcast_domain_too_large_enabled", 0)
	end

	-- #################################################################


- :code:`onEnable()`: function called when the check is enabled;
- :code:`onDisable()`: function called when the check is disabled;
- :code:`onLoad()`: function called when the check is loaded (e.g. at startup);
- :code:`onUnload()`: function called when the check is unloaded (e.g. when shutting down);
- :code:`setup()`: function called at startup, if a false is returned the check is not going to be show in the GUI;
- :code:`teardown()`: called after the script operation is complete (e.g. after all the hosts have been iterated and hooks called).


Alert ID 
========

The Alert ID is a unique idetifier, that identifies the alerts between each other.

Simply add a new entry in the :code:`scripts/lua/modules/alert_keys/other_alert_keys.lua` file.

Add :code:`other_alert_example` to the table:

.. code:: lua

   alert_exporters_limit_exceeded       = OTHER_BASE_KEY + 96,
   alert_acl_violation_arp              = OTHER_BASE_KEY + 97,
   other_alert_example              	= OTHER_BASE_KEY + 98,
   
   MAX_OTHER_ALERT_TYPE = OTHER_BASE_KEY + 127 -- see ntop_typedefs.h
}

.. note::

  Alert keys are guaranteed to be constant and never changing, even across ntopng releases.

.. warning::

  Prior to 2020-04-15 there was no concept of :code:`alert_key`. Backward compatibility with alerts generated before that date is not ensured.


Create the Alert Script
=======================

Lastly a script that describes the alert (the specific triggered alert) is needed.

Create an other script :code:`alert_my_example_alert` in the :code:`scripts/lua/modules/alert_definitions/other` folder

.. note::

  The file name of the alert and the alert type when creating the alert (alert_consts.alert_types.alert_my_example_alert.new) MUST be the same


.. code:: lua

	local other_alert_keys = require "other_alert_keys"
	local alert_creators = require "alert_creators"
	local classes = require "classes"
	local alert = require "alert"
	local alert_entities = require "alert_entities"

	-- ##############################################

	local alert_my_example_alert = classes.class(alert)

	-- ##############################################

	alert_my_example_alert.meta = {
		alert_key = other_alert_keys.other_alert_example, -- Alert ID previously added
		i18n_title = "alerts_dashboard.check_example_title",
		icon = "fas fa-fw fa-sign-in", -- Icon
		entities = {
			alert_entities.network -- Which is the Entity of the alert? In our case network
		},
	}

	-- ##############################################

	-- This function is called when creating the alert
	function alert_my_example_alert:init(my_value_to_check, threshold)
		-- Call the parent constructor
		self.super:init()

		-- Add this only if custom fields are used, e.g. my_value_to_check and threshold
		self.alert_type_params = {
			my_value_to_check = my_value_to_check,
			threshold = threshold
		}
	end

	-- #######################################################

	-- This function is used to display the results in the Alerts Page (when displaying the alert)
	function alert_my_example_alert.format(ifid, alert, alert_type_params)
		return i18n('alerts_dashboard.alert_my_example_alert_descr', { num = alert_type_params.my_value_to_check, threshold = threshold })
	end

	-- #######################################################

	return alert_my_example_alert


- :code:`alert_my_example_alert.meta`: here the information regarding the alerts needs to be added:

	- :code:`alert_key`: The Alert ID previously added;
	- :code:`i18n_title`: The title displayed when showing the alert (suggestion: use the same i18n_title as in the GUI section when creating the check);
	- :code:`icon`: A Font Awesome 5 icon shown next to the :code:`i18n_title`.
	- :code:`entities`: An entity is needed here, basically the alert is created for networks alerts, so use the network entity; a list of entities here: scripts/lua/modules/alert_entities.lua;
- :code:`alert_my_example_alert:init`: this function is called when the alert is created (when calling the new in the check), if custom parameters are needed, pass them here and assign those parameters at the :code:`self.alert_type_params`
- :code:`alert_my_example_alert.format`: this function is called to display the alert message, so when displaying the triggered alert; the parameters passed in the new can be retrieved from :code:`alert_type_params`
