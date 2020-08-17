.. _Alert Endpoints:

Alert Endpoints
===============

When an alert occurs, ntopng exports the alert to the `configured endpoints`_.
By creating a custom endpoint, users can easily export the alert data to their preferred service or
trigger a specialized action based on the triggered alert.

How They Work
-------------

Each alert endpoint has a dedicated redis FIFO queue. When an alert is triggered, ntopng enqueues the
alerts JSON representation to each one of the enabled endpoints queues. Periodically ntopng invokes the
endpoint logic which is responsible for dequeuing alerts from the queue and process them.

Endpoints Definition
--------------------

The endpoints are defined into the `./alert_endpoints` subdirectory of the plugin. Let's analyze the
`email_alert_endpoint`_  as an example.

Endpoint Script
~~~~~~~~~~~~~~~

The file `email.lua` contains the actual logic of the endpoint. The module has the following structure:

- :code:`endpoint.EXPORT_FREQUENCY`: defines the invocation frequency of `endpoint.dequeueRecipientAlerts`. Usually 60 seconds
  is fine for most practical cases.
- :code:`endpoint.prio`: defines the priority for the execution of `endpoint.dequeueRecipientAlerts` in relation to other endpoints.
  Endpoints with higher priority will be invoked first (so they are privileged, in particular when the time is strict).
- :code:`endpoint.onLoad()`: can be used to programmatically perform certain actions when the plugin is loaded.
- :code:`endpoint.isAvailable()`: can be used to programmatically disable the endpoint (e.g. disable the endpoint on
  some platform). Must return true if the endpoint can be currently used (once the user enables it from the
  endpoints preferences), or false if the endpoint should not be used and its preferences should be hidden.
- :code:`endpoint.dequeueRecipientAlerts(recipient, budget)`: called periodically (based on the `endpoint.EXPORT_FREQUENCY`).
  The endpoint is expected to dequeue the alerts from the provided `recipient.export_queue` and process them, up to `budget`. 
  The function must return `{success=true}` if  the alerts could be processed correctly, otherwise `{success=false, error_message="something went wrong"}` 
  which some useful error message which will be reported to the user.
- :code:`endpoint.runTest()`: it's invoked to validate the configuration, e.g. sending a test email to verify that it works. 
  On success it  should return `nil`, on failure it should return `message_info, message_severity` where `message_info` is 
  a localized message to show on the GUI and `message_severity` is the CSS class to apply on the message box.

Preferences Definition
~~~~~~~~~~~~~~~~~~~~~~

The script `email.lua` defines the configuration parameters for the endpoint and the recipient
at the beginning of the file:

.. code:: lua

   local email = {
     conf_params = {
       { param_name = "smtp_server" },
       { param_name = "email_sender"},
       { param_name = "smtp_username", optional = true },
       { param_name = "smtp_password", optional = true },
     },
     conf_template = {
       plugin_key = "email_alert_endpoint",
       template_name = "email_endpoint.template"
     },
     recipient_params = {
       { param_name = "email_recipient" },
       { param_name = "cc", optional = true },
     },
     recipient_template = {
       plugin_key = "email_alert_endpoint",
       template_name = "email_recipient.template"
     },
   }

Example
-------

Here is a commented snippet for the email endpoint.

.. code:: lua

  local email = {
    conf_params = {
      { param_name = "smtp_server" },
      { param_name = "email_sender"},
      { param_name = "smtp_username", optional = true },
      { param_name = "smtp_password", optional = true },
    },
    conf_template = {
      plugin_key = "email_alert_endpoint",
      template_name = "email_endpoint.template"
    },
    recipient_params = {
      { param_name = "email_recipient" },
      { param_name = "cc", optional = true },
    },
    recipient_template = {
      plugin_key = "email_alert_endpoint",
      template_name = "email_recipient.template"
    },
  }

  -- email.dequeueRecipientAlerts will be invoked every 60 seconds
  email.EXPORT_FREQUENCY = 60

  -- It is suggested to bulk multiple alerts into a single message when
  -- possible
  local MAX_ALERTS_PER_EMAIL = 100

  -- ##############################################

  function email.isAvailable()
    -- ntop.sendMail is not available on some platforms (e.g. Windows),
    -- so on such platforms this endpoint should be disabled.
    return(ntop.sendMail ~= nil)
  end

  -- ##############################################

  -- This is a custom function defined public with the purpose of allowing
  -- other code to call it.
  function email.sendEmail(subject, message_body)
    ...

    return ntop.sendMail(from, to, message, smtp_server, username, password)
  end

  -- ##############################################

  -- The function in charge of dequeuing alerts. Some code is boilerplate and
  -- can be copied to new endpoints.
  function my_endpoint.dequeueRecipientAlerts(recipient, budget)
    local processed = 0
	
    while processed < budget do
      -- Retrieve a bulk of MAX_ALERTS_PER_EMAIL (or less) alerts
      local alerts = ntop.lrangeCache(recipient.export_queue, 0, MAX_ALERTS_PER_EMAIL-1)

      if not alerts then
        break
      end

      -- Aggregate the alerts into a single message body
      local message_body = {}

      for _, json_message in ipairs(alerts) do
        -- From JSON string to Lua table
        local alert = json.decode(json_message)

        -- Get a standard message for the alert
        message_body[#message_body + 1] = alert_utils.formatAlertNotification(alert, {nohtml=true})
      end

      if email.sendEmail(subject, message_body) then
        -- IMPORTANT: remove the processed messages from the queue
        ntop.ltrimCache(recipient.export_queue, MAX_ALERTS_PER_EMAIL, -1)
      else
        -- NOTE: The messages will be kept into the queue. Export will be
        -- retried at the next round
        return {success=false, error_message="Could not contact the SMTP server"}
      end
	  
	  processed = processed + 1
    end
	
	return {success=true}
  end

  -- ##############################################

  return email

It's very important to remove the processed alerts from the queue (see `ntop.ltrimCache` above) in
order to make space for new alerts and avoid processing them again.

Alert Format
------------

By using the `alert_utils.formatAlertNotification` function it is not necessary to know the internal alerts format, however
it is in order to perform specific actions based on the alert. The alerts in the queue have the following format:

- :code:`ifid`: the interface id on which the alert has been generated.
- :code:`action`: `engage`, `release` or `store`. Check the alerts API for more details. [4]
- :code:`alert_tstamp`: the Unix timestamp when the alert was triggered
- :code:`alert_tstamp_end`: in case of released alerts, contains the Unix timestamp of the release event
- :code:`alert_type`: the `alert type`_ ID. `alert_consts.alertTypeRaw` can be used to convert it to a string.
- :code:`alert_subtype`: an optional alert subtype.
- :code:`alert_severity`: the `alert severity`_ ID. `alertSeverityRaw` can be used to convert it to a string.
- :code:`alert_json`: a JSON which contains information which is specific for the alert_type.
- :code:`alert_entity`: the `alert entity`_ ID. `alert_consts.alertEntityRaw` can be used to convert it to a string.
- :code:`alert_entity_val`: the alert entity value (e.g. the IP of the host involved).
- :code:`alert_granularity`: the alert granularity, which is how often the alert check is performed.

Here is an example of a threshold cross alert on the minute packets for an host:

.. code:: json

  {
    "alert_tstamp": 1585579981,
    "alert_entity": 1,
    "alert_entity_val": "140.82.114.26@0",
    "alert_granularity": 60,
    "action": "engage",
    "alert_type": 32,
    "alert_subtype": "packets",
    "ifid": 1,
    "alert_json": "{\"threshold\":1,\"alert_generation\":{\"subdir\":\"host\",\"script_key\":\"packets\",\"confset_id\":0},\"operator\":\"gt\",\"value\":12,\"metric\":\"packets\"}",
    "alert_severity": 2,
    "alert_tstamp_end": 1585579981
  }

This information can be used to perform customized actions when an alert occurs. The following example shows
how to log to console `flow flood attackers alerts`_.

.. code:: lua

  local my_endpoint = {
    conf_params = {
    },
    conf_template = {
      plugin_key = "my_endpoint_alert_endpoint",
      template_name = "my_endpoint_endpoint.template"
    },
    recipient_params = {
    },
    recipient_template = {
      plugin_key = "my_endpoint_alert_endpoint",
      template_name = "my_endpoint_recipient.template"
    },
  }
  
  my_endpoint.EXPORT_FREQUENCY = 60

  function my_endpoint.dequeueRecipientAlerts(recipient, budget)
    local alert_consts = require("alert_consts")
    local alert_utils = require("alert_utils")
    local processed = 0
	
    while processed < budget do
      -- Process 100 alerts at a time
      local bulk_size = 100
      local alerts = ntop.lrangeCache(recipient.export_queue, 0, bulk_size)

      if not alerts then
        break
      end

      for _, json_message in ipairs(alerts) do
        -- From JSON string to Lua table
        local alert = json.decode(json_message)

        if((alert_consts.alertEntityRaw(alert.alert_entity) == "host") and
          (alert_consts.alertTypeRaw(alert.alert_type) == "alert_flows_flood") and
          (alert.alert_subtype == "flow_flood_attacker")) then
           -- Put your custom action here
           traceError(TRACE_NORMAL, TRACE_CONSOLE, "Flow Flood Attacker: " .. alert_utils.formatAlertNotification(alert, {nohtml=true}))
        end
      end

      -- IMPORTANT: remove the processed messages from the queue
      ntop.ltrimCache(recipient.export_queue, bulk_size, -1)

      processed = processed + 1
    end
	
	return {success=true}
  end

  return my_endpoint

.. _`configured endpoints`: ../web_gui/alerts.html#alert-endopints
.. _`email_alert_endpoint`: https://github.com/ntop/ntopng/tree/dev/scripts/plugins/email_alert_endpoint
.. _`prefs_menu.lua`: https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/prefs_menu.lua
.. _`Localization section`: https://www.ntop.org/guides/ntopng/plugins/localization.html
.. _`prefs_utils.lua`: https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/prefs_utils.lua
.. _`flow flood attackers alerts`: https://github.com/ntop/ntopng/tree/dev/scripts/plugins/flow_flood
.. _`alert severity`: https://www.ntop.org/guides/ntopng/basic_concepts/alerts.html#severity
.. _`alert entity`: https://www.ntop.org/guides/ntopng/basic_concepts/alerts.html#entities
.. _`alert type`: https://www.ntop.org/guides/ntopng/basic_concepts/alerts.html#type
