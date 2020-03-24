.. _Alert Definitions:

Alert Definitions
=================

A plugin may need to generate alerts when it detects a certain
condition. All the alerts a plugin is willing to generate require a
file in plugin sub-directory :code:`./alert_definitions/`. The file
contains all the necessary information which is required to properly
show and format an alert.

The file can contain one or more functions to properly format the
alert and it must return a lua table with the following keys:

- :code:`i18n_title`: Is a string indicating the title of the
  alert. The string is first looked up among the localized strings
  under the plugin directory :code:`./locales`, then among the localized strings
  under the ntopng :code:`scripts/locales` directory and, finally, if
  no localization is found, the string is taken verbatim. When a
  string is searched among the localized strings, it is considered as a key of
  the localization lua table. Points :code:`.` present in the string
  are used to search among localization sub-tables. For example,
  string :code:`alerts_dashboard.blacklisted_flow` is localized when the
  localization table contains a table :code:`alerts_dashboard` which,
  in turn, contains a key :code:`blacklisted_flow`.
- :code:`i18n_description` (optional): Is either a string with the alert
  description or a function returning the alert description.
  a string. When it is a string, the same logic described for
  the :code:`i18n_title` is applied. When it is a function, it gets
  called by the plugin with certain parameters and it returns
  the alert description. Parameters can be used to augment the
  alert description with information on the current alert that is being
  triggered. For example, a parameter can be the interface id, and
  another parameter can be the IP address of an host. Localization
  :code:`i18n` is available as well so that the function can produce a
  localized description.
- :code:`icon` (optional): A Font Awesome 5 icon shown next to the :code:`i18n_title`.

Examples
--------

Let's have a look at a couple of examples. Let's start with plugin
:ref:`Blacklisted Flows` created in the :ref:`Plugin Examples`. It's
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

Let's now move to the other example plugin :ref:`Flow Flooders`.
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
