.. _Check Hooks:

Check Hooks
=================

ntopng uses hooks to know when to execute a check. Hooks are string keys of the plugin :code:`hooks` table and have a check function assigned. Hooks are associated to:

- Predefined events for flows
- Intervals of time for any other network element such as an host, or a network

:ref:`Flow Check Hooks` and :ref:`Other Check Hooks` are discussed below.

.. _Flow Check Hooks:

Flow Check Hooks
----------------------

Available hooks for flow checks are the following:

- :code:`protocolDetected`: Called after the Layer-7 application protocol has been detected.
- :code:`statusChanged`: Called when the internal status of the flow has changed since the previous invocation.
- :code:`periodicUpdate`: Called every few minutes on long-lived flows.
- :code:`flowEnd`: Called when the flow is considered finished.
- :code:`all`: A special hook which will cause the associated check to be called for all the available hooks.

Flow Check Hooks Parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ntopng calls flow checks with two parameters:

- :code:`now`: An integer indicating the current epoch
- :code:`script_config`: A table containing the check configuration submitted by the user from the :ref:`Web GUI`. Table can be empty if the script doesn not require user-submitted configuration.

Flow Check Hook Example
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A check which needs to be called every time a flow goes idle, will implement a check function and assign it to hook :code:`flowEnd`.

.. code:: lua

  hooks = {
    flowEnd  = function (now, script_config)
      --[[ Check function body --]]
    end
  }


.. _Other Check Hooks:

Other Check Hooks
-----------------------

Available hooks for non-flow checks are the following:

- :code:`min`: Called every minute.
- :code:`5mins`: Called every 5 minutes.
- :code:`hour`: Called every hour.
- :code:`day`: Called every day (at midnight localtime).
- :code:`all`: A special hook name which will cause the associated check to be called for all the available hooks.

Other Check Hooks Parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ntopng calls every check hook function with a :code:`params` Lua table as argument. The script hook function is expected to have this structure:

.. code:: lua

  function my_check(params)
    -- ...
  end

The :code:`params` contains the following keys:

- :code:`granularity`: one of :code:`aperiodic`, :code:`min`, :code:`5mins`, :code:`hour`, :code:`day`.
- :code:`alert_entity`: A table carrying information on the current entity which can be used to generate alerts.
- :code:`entity_info`: A string identifying the current entity.
- :code:`cur_alerts`: Currently engaged alert for the entity.
- :code:`check_config`: The check configuration submitted by the user from the :ref:`Web GUI`. Table can be empty if the script doesn not require user-submitted configuration.
- :code:`check`: The name of the check which is being called.
- :code:`when`: An integer indicating the current epoch.
- :code:`ifid`: The interface id of the current interface.
- :code:`ts_enabled`: True when the timeseries generation is enabled for the current timeseries.

It is ntopng which takes care of calling the hook check function with table :code:`params` opportunely populated.


Other Check Hooks Example
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A check which needs to be called every minute will implement a check function and assign it to hook :code:`min`

.. code:: lua

  hooks = {min  = function (params) --[[ Check function body --]] end }


