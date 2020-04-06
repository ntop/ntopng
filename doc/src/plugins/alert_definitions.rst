.. _Alert Definitions:

Alert Definitions
=================

A plugin enables alerts to be generated. All the alerts a plugin is willing to generate require a file in plugin subdirectory :code:`./alert_definitions/`. The file contains all the necessary information which is required to properly show, localize and format an alert.

The file must return a Lua table with the following keys:

- :code:`i18n_title`: A string indicating the title of the
  alert. ntopng localizes the string as described in :ref:`Plugin Localization`.
- :code:`i18n_description` (optional): Either a string with the alert
  description or a function returning an alert description string. When :code:`i18n_description` is a string, ntopng localizes as described in :ref:`Plugin Localization`.
- :code:`icon`: A Font Awesome 5 icon shown next to the :code:`i18n_title`.

.. _Alert Description:

Alert Description
-----------------

Alert description :code:`i18n_description` can be either a string with the alert description or a function returning an alert description string.

String
~~~~~~

When the alert description is string, it is localized as described in :ref:`Plugin Localization`. An :code:`alert_json` table is passed as the parameters table for the localization. Keys and values of :code:`alert_json` can be used to add parameters to the localization string. Refer to :ref:`Triggering Alerts` to see how to create and :code:`alert_json`.

Function
~~~~~~~~

When the alert description is a function, it gets called with three parameters:

- :code:`ifid`: An integer number uniquely identifying the interface which is triggering the alert.
- :code:`alert`: A Lua table containing the details of the alert.
- :code:`alert_json`: A Lua table that can be used to add parameters to the localization string.

Refer to :ref:`Triggering Alerts` for additional details on these three parameters.

The function is expected to return a string which is possibly localized. It is up to the plugin to call the :code:`i18n()` localization function to do the actual localization. ntopng will not perform any localization on the returned value of the function.

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
keys. :code:`i18n_title` is localized in `en.lua <https://github.com/ntop/ntopng/blob/dev/scripts/locales/en.lua>`_ and other localization files. :code:`icon` is used to select the `warning sign <https://fontawesome.com/icons/exclamation-triangle>`_ which will be printed
next to the title. :code:`i18n_description` has been omitted as the alert does not need any extra description apart from the title.

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
called automatically with the three parameters as described above. This function uses
:code:`alert_consts.formatAlertEntity` to properly format the alert
(remember that either an host or a network can be a flooder) and then
returns an :code:`i18n` localized string.
