User Scripts API
================

User Scripts provide a way for lua scripts to be called when a particular event occurs.
ntopng provides some built in scripts which carry out its internal operations. Users can create
their custom scripts and attach them to some hooks in order to perform custom operations.

As an example, in order to log the detected flows details, the following script can be created and
placed under the `/usr/share/ntopng/user_scripts/flows` directory:

.. code:: lua

  local user_scripts = require("user_scripts")

  -- #################################################################

  -- The callback function to be called
  function logDetectedFlow(params)
    print("Detected Flow: ".. shortFlowLabel(flow.getInfo()) .."\n")
  end

  -- #################################################################

  local script = {
    -- A unique key for the script
    key = "flow_logger",

    hooks = {
      -- Attach an hook to the protocolDetected event
      protocolDetected = logDetectedFlow,
    },
  }

  -- #################################################################

  return(script)

The example above uses `flow.getInfo()` to extract all the information for the
current flow. While this is very pratical, it is an expensive operation so scripts
operating in large networks should instead call specific methods which are documented
below.

.. toctree::

    common_structure.rst
    flow_hooks.rst
    traffic_element_hooks.rst
    alerts.rst
    syslog.rst
