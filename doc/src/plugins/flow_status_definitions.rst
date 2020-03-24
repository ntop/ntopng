.. _Flow Definitions:

Flow Status Definitions
=======================

A plugin enables on or more statuses to be set on certain flows. A flow can have multiple statuses associated. An alert can be associated to each status. Flow statuses must be defined in :code:`./status_definitions/` and they are set calling :code:`flow.triggerStatus`. Definition is done using a Lua files, one file per status.

A flow status definition file must return a lua table with the following keys:

- :code:`i18n_title`: A title for the flow status. This title is shown within the ntopng Web UI, for example to filter active flows on their status, or when browsing historical flows. For the rules of how to specify this title, refer to :code:`i18n_title` in :ref:`Alert Definitions`.
- :code:`i18n_description`: A description for the flow status. This description is shown within the web user interface and follows the same rules as the :code:`i18n_description` in :ref:`Alert Definitions`.
- :code:`alert_type` (optional): When an alert needs to be associated to the status, this key must be present. Key has the structure :code:`alert_consts.alert_types.<an alert key>`, where :code:`<an alert key>` is the file name of an alert definition without the :code:`.lua` suffix.
- :code:`alert_severity` (optional): When an alert needs to be associated to the status, this key indicated the severity of the alert. Key has the structure :code:`alert_consts.alert_severities.<alert severity>`, where :code:`<alert severity>` is one among the available `alert severities <https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/alert_consts.lua>`_.

Example
-------

Example considers :ref:`Blacklisted Flows` plugin created in the :ref:`Plugin Examples`. It's :code:`./status_definitions` `sub-directory <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/blacklisted/status_definitions>`_ contains file :code:`status_blacklisted.lua`. Contents of this file are

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


This file returns a Lua table with the keys as highlighted above. The :code:`i18n_description` is a function which receives as input parameter a table with the flow details, and return a localized string built using the flow details received as input.
