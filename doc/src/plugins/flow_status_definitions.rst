.. _Flow Definitions:

Flow Status Definitions
=======================

A plugin enables one or more statuses to be set on certain flows. A flow can have multiple statuses set and statuses can be associated to alerts. Flow statuses must be defined in plugin sub-directory :code:`./status_definitions/` and they are set calling :code:`flow.triggerStatus`. Definition is done using a Lua files, one file per status.

A flow status definition file must return a Lua table with the following keys:

- :code:`i18n_title`: A string indicating the title of the status. ntopng localizes the string as described in :ref:`Plugin Localization`.
- :code:`i18n_description` (optional): Either a string with the flow status description or a function returning a flow status description string. When :code:`i18n_description` is a string, ntopng localizes as described in :ref:`Plugin Localization`.
- :code:`alert_type` (optional): When an alert is associated to the flow status, this key must be present. Key has the structure :code:`alert_consts.alert_types.<an alert key>`, where :code:`<an alert key>` is the name of a file created in :ref:`Alert Definitions`, without the :code:`.lua` suffix.
- :code:`alert_severity` (optional): When an alert is associated to the flow status, this key indicates the severity of the alert. Key has the structure :code:`alert_consts.alert_severities.<alert severity>`, where :code:`<alert severity>` is one among the available `alert severities <https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/alert_consts.lua>`_.

.. _Flow Status Description:

Flow Status Description
-----------------------

Flow Status description :code:`i18n_description` can be either a string with the flow status description or a function returning a flow status description string.

String
~~~~~~

When the flow status description is string, it is localized as described in :ref:`Plugin Localization`. A :code:`flowstatus_info` table is passed as the parameters table for the localization. Keys and values of :code:`flowstatus_info` can be used to add parameters to the localization string. Refer to :ref:`Flow User Scripts` to see how to create and pass :code:`flowstatus_info`.

Function
~~~~~~~~

When the flow status description is a function, it gets called with one parameter:

- :code:`flowstatus_info`: A Lua table containing the details of the flow status.

Refer to :ref:`Flow User Scripts` for additional details on this parameter.

The function is expected to return a string which is possibly localized. It is up to the plugin to call the :code:`i18n()` localization function to do the actual localization. ntopng will not perform any localization on the returned value of the function.


Example
-------

Consider :ref:`Blacklisted Flows` plugin created in the :ref:`Plugin Examples`. It's :code:`./status_definitions` `sub-directory <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/blacklisted/status_definitions>`_ contains file :code:`status_blacklisted.lua`. Contents of this file are

.. code:: lua

     local alert_consts = require("alert_consts")

     -- #################################################################

     local function formatBlacklistedFlow(flowstatus_info)
	local who = {}

	if not flowstatus_info then
	   return i18n("flow_details.blacklisted_flow")
	end

	if flowstatus_info["blacklisted.cli"] then
	   who[#who + 1] = i18n("client")
	end

	if flowstatus_info["blacklisted.srv"] then
	   who[#who + 1] = i18n("server")
	end

	-- if either the client or the server is blacklisted
	-- then also the category is blacklisted so there's no need
	-- to check it.
	-- Domain is basically the union of DNS names, SSL CNs and HTTP hosts.
	if #who == 0 and flowstatus_info["blacklisted.cat"] then
	   who[#who + 1] = i18n("domain")
	end

	if #who == 0 then
	   return i18n("flow_details.blacklisted_flow")
	end

	local res = i18n("flow_details.blacklisted_flow_detailed", {who = table.concat(who, ", ")})

	return res
     end

     -- #################################################################

     return {
       alert_severity = alert_consts.alert_severities.error,
       alert_type = alert_consts.alert_types.alert_flow_blacklisted,
       i18n_title = "flow_details.blacklisted_flow",
       i18n_description = formatBlacklistedFlow
     }


This file returns a Lua table with four keys. An alert is associated to :code:`status_blacklisted`, so both keys :code:`alert_severity` and :code:`alert_type` must be specified. Key :code:`alert_type` indicates the alert which is going to be triggered is :code:`alert_flow_blacklisted`. ntopng retrieves the alert definition as there is an alert definition file `alert_flow_blacklisted.lua <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/blacklisted/alert_definitions/alert_flow_blacklisted.lua>`_.

The :code:`i18n_description` is assigned to the :code:`local function formatBlacklistedFlow`. ntopng will call this function to generate the description of the status. The function takes care of producing a formatted, localized output.
