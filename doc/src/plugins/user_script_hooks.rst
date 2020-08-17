.. _User Script Hooks:

User Script Hooks
=================

ntopng uses hooks to know when to execute a user script. Hooks are string keys of the plugin :code:`hooks` table and have a callback function assigned. Hooks are associated to:

- Predefined events for flows
- Intervals of time for any other network element such as an host, or a network

:ref:`Flow User Script Hooks` and :ref:`Other User Script Hooks` are discussed below.

.. _Flow User Script Hooks:

Flow User Script Hooks
----------------------

Available hooks for flow user scripts are the following:

- :code:`protocolDetected`: Called after the Layer-7 application protocol has been detected.
- :code:`statusChanged`: Called when the internal status of the flow has changed since the previous invocation.
- :code:`periodicUpdate`: Called every few minutes on long-lived flows.
- :code:`flowEnd`: Called when the flow is considered finished.
- :code:`all`: A special hook which will cause the associated callback to be called for all the available hooks.

Flow User Script Hooks Parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ntopng calls flow user scripts with two parameters:

- :code:`now`: An integer indicating the current epoch
- :code:`script_config`: A table containing the user script configuration submitted by the user from the :ref:`Web GUI`. Table can be empty if the script doesn not require user-submitted configuration.

Flow User Script Hook Example
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A user script which needs to be called every time a flow goes idle, will implement a callback function and assign it to hook :code:`flowEnd`.

.. code:: lua

  hooks = {
    flowEnd  = function (now, script_config)
      --[[ Callback function body --]]
    end
  }


.. _Other User Script Hooks:

Other User Script Hooks
-----------------------

Available hooks for non-flow user scripts are the following:

- :code:`min`: Called every minute.
- :code:`5mins`: Called every 5 minutes.
- :code:`hour`: Called every hour.
- :code:`day`: Called every day (at midnight localtime).
- :code:`all`: A special hook name which will cause the associated callback to be called for all the available hooks.

Other User Script Hooks Parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ntopng calls every user script hook function with a :code:`params` Lua table as argument. The script hook function is expected to have this structure:

.. code:: lua

  function my_callback(params)
    -- ...
  end

The :code:`params` contains the following keys:

- :code:`granularity`: one of :code:`aperiodic`, :code:`min`, :code:`5mins`, :code:`hour`, :code:`day`.
- :code:`alert_entity`: A table carrying information on the current entity which can be used to generate alerts.
- :code:`entity_info`: A string identifying the current entity.
- :code:`cur_alerts`: Currently engaged alert for the entity.
- :code:`user_script_config`: The user script configuration submitted by the user from the :ref:`Web GUI`. Table can be empty if the script doesn not require user-submitted configuration.
- :code:`user_script`: The name of the user script which is being called.
- :code:`when`: An integer indicating the current epoch.
- :code:`ifid`: The interface id of the current interface.
- :code:`ts_enabled`: True when the timeseries generation is enabled for the current timeseries.

It is ntopng which takes care of calling the hook callback function with table :code:`params` opportunely populated.


Other User Script Hooks Example
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A user script which needs to be called every minute will implement a callback function and assign it to hook :code:`min`

.. code:: lua

  hooks = {min  = function (params) --[[ Callback function body --]] end }


