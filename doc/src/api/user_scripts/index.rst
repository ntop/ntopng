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

  local script = {
    -- A unique key for the script
    key = "flow_logger",

    -- Hooks are defined below
    hooks = {},
  }

  -- #################################################################

  -- Attach a callback to the protocolDetected hook
  function script.hooks.protocolDetected(params)
    print("Detected Flow: ".. shortFlowLabel(flow.getInfo()) .."\n")
  end

  -- #################################################################

  return(script)

The example above uses `flow.getInfo()` to extract minimal information for the
current flow and prints it into the console.

.. toctree::

    definitions.rst
    common_structure.rst
    flow_hooks.rst
    traffic_element_hooks.rst
    alerts.rst
    syslog.rst
