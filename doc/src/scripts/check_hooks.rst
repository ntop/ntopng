.. _Check Hooks:

Check Hooks
===========

ntopng uses hooks to know when to execute a check. Hooks are string keys of the script :code:`hooks` table and have a check function assigned. Hooks are associated to intervals of time for any network element (e.g. a network).

Flow and host checks are currently implemented in C++. Checks for other network elements are implemented in Lua and the below hooks are available:

- :code:`min`: Called every minute.
- :code:`5mins`: Called every 5 minutes.
- :code:`hour`: Called every hour.
- :code:`day`: Called every day (at midnight localtime).
- :code:`all`: A special hook name which will cause the associated check to be called for all the available hooks.

Hooks Parameters
~~~~~~~~~~~~~~~~

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

Hooks Example
~~~~~~~~~~~~~

A check which needs to be called every minute will implement a check function and assign it to hook :code:`min`

.. code:: lua

  hooks = {min  = function (params) --[[ Check function body --]] end }


