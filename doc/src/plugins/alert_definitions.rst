.. _Alert Definitions:

Alert Definitions
=================

A plugin enables alerts to be generated. All the alerts a plugin is willing to generate require a
file in plugin sub-directory :code:`./alert_definitions/`. The file
contains all the necessary information which is required to properly
show, localize and format an alert.

The file must return a Lua table with the following keys:

- :code:`i18n_title`: A string indicating the title of the
  alert. ntopng localizes the string as described in :ref:`Plugin Localization`.
- :code:`i18n_description` (optional): Either a string with the alert
  description or a function returning an alert description string. When :code:`i18n_description` is a string, ntopng localizes as described in :ref:`Plugin Localization`.
- :code:`icon`: A Font Awesome 5 icon shown next to the :code:`i18n_title`.

.. _Alert Description:

Alert Description
-----------------

String
~~~~~~

Function
~~~~~~~~

When it is a function, it gets called by the plugin with certain parameters. Parameters can be used to augment the alert with additional information on the alert itself. Localization :code:`i18n` is available inside the function so that it can produce a localized description. See :ref:`Alert Description` below for additional details and examples.

Examples
--------

The first example considers :ref:`Blacklisted Flows` created in the :ref:`Plugin Examples`. It's
:code:`./alert_definitions` `sub-directory <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/blacklisted/alert_definitions>`_ contains file :code:`alert_flow_blacklisted.lua`. Contents of this file are

.. code:: lua

   return {
     i18n_title = "alerts_dashboard.blacklisted_flow",
     icon = "fas fa-exclamation",
   }

This file is very simple as it just :code:`return` s a table with two
keys. :code:`i18n_title` is localized as
:code:`scripts/locales/en.lua` and other localization files contain a table
:code:`alerts_dashboard` with a key :code:`blacklisted_flow`. Then,
:code:`icon` is used to select the `warning sign <https://fontawesome.com/icons/exclamation-triangle>`_ which will be printed
next to the title. :code:`i18n_description` has been omitted as the
:ref:`Flow Definitions` format function is re-used.

Second example considers plugin :ref:`Flow Flooders`.
It's :code:`./alert_definitions` `sub-directory <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/flow_flood/alert_definitions>`_ contains file :code:`alert_flows_flood.lua`. Contents of this file are

.. code:: lua

     local function formatFlowsFlood(ifid, alert, threshold_info)
       local alert_consts = require("alert_consts")
       local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
       local value = threshold_info.value

       if(value == nil) then value = 0 end

       if(alert.alert_subtype == "flow_flood_attacker") then
	 return i18n("alert_messages.flow_flood_attacker", {
	   entity = firstToUpper(entity),
	   value = string.format("%u", math.ceil(value)),
	   threshold = threshold_info.threshold,
	 })
       else
	 return i18n("alert_messages.flow_flood_victim", {
	   entity = firstToUpper(entity),
	   value = string.format("%u", math.ceil(value)),
	   threshold = threshold_info.threshold,
	 })
       end
     end

     -- #######################################################

     return {
       i18n_title = "alerts_dashboard.flows_flood",
       i18n_description = formatFlowsFlood,
       icon = "fas fa-life-ring",
     }

The file returns a table with the keys as described above. However,
here, :code:`i18n_description` is a function. This function will be
called automatically with three parameters, namely the interface id of
the interface which is triggering the alert, an alert table, and information
on the exceeded threshold. This function uses
:code:`alert_consts.formatAlertEntity` to properly format the alert
(remember that either an host or a network can be a flooder) and then
returns an :code:`i18n` localized string.
