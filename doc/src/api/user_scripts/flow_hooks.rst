Flow Scripts
############

Flow scripts are executed on each network flow. The user can inspect the
flow protocol, peers involved in the communication, and other specific information.

Hooks
-----

A user script can hook the following functions:

  - `protocolDetected`: called after the Layer-7 application protocol has been detected
  - `statusChanged`: called when the internal status of the flow has changed
    since the previous invocation. The flow status can be used to detect anomalous behaviours.
  - `periodicUpdate`: called every few minutes on long-lived flows
  - `flowEnd`: called when the flow is considered finished

`all` can be used to register to all the functions.

Example: Country based Alert
----------------------------

Let's see how to create a custom script which checks flow client and server countries,
and perform certain actions when either the client or the server is found to be from a country (China in this example).
As this script should be executed as early as possible in the lifecycle of a flow, the `protocolDetected` hook is used to do the check on the countries and to perform the actions.

The script can be written to file `suspicious_countries.lua`. Although any file name is valid,
it is recommended to pick a name which is somehow indicative of the actual script actions.
To make sure ntopng will execute it, `suspicious_countries.lua` must be placed under directory
`/usr/share/ntopng/scripts/callbacks/interface/flow`.


.. code:: lua

  local user_scripts = require("user_scripts")

  -- #################################################################

  local script = {
     key = "suspicious_countries",
     hooks = {},

     gui = {
        i18n_title = "Suspicious Countries",
        i18n_description = "Trigger an alert when at least one among the client and server is from a suspicious country",
        input_builder = user_scripts.flow_checkbox_input_builder,
     }
  }

  -- #################################################################

  function script.hooks.protocolDetected()
     local cli_geo = flow.getClientGeolocation()
     local srv_geo = flow.getServerGeolocation()

     if cli_geo["cli.country"] == "CN" or srv_geo["srv.country"] == "CN" then
        tprint("From China") -- this will print the message "From China" to the standard output
        -- Execute custom actions:
        -- Raise an alert...
        -- Increase the flow score...
     end
  end

  -- #################################################################

  return(script)

The script logic resides into the `script.hooks.protocolDetected` function.
The `flow` object keeps a context of the currently processed flow.
The `flow.getClientGeolocation` and `flow.getServerGeolocation` functions extract the peers country information.
The country code is then processed to determine if any of the peers is located in China (country code `CN`).

An easier way to access all the flow information would be to call `flow.getFullInfo()`, but this should not be used in
production as it's a very expensive call.

See the `Flow API`_ for a documentation of the available functions.

.. _`Flow API`: ../lua_c/flow/index.html
