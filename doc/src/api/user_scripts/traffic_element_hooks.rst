Traffic Element Scripts
#######################

ntopng supports users scripts on the following traffic elements:

  - `interface`: a network interface of ntopng
  - `network`: a local network of ntopng
  - `host`: a local/remote host of ntopng

Hooks
-----

Traffic element scripts are called periodically. The corresponding available hooks are:

  - `min`: called every minute
  - `5mins`: called every 5 minutes
  - `hour`: called every hour
  - `day`: called every day (at midnight)

`all` can be used to register to all the functions.

Example: Export active hosts list
---------------------------------

The following example shows how to dump the active hosts list of ntopng
every minute and send it to a remote server:

.. code:: lua

  local user_scripts = require("user_scripts")
  local json = require("dkjson")

  -- Will be used to keep track of all the hosts
  local hosts_list

  local script = {
    key = "dump_active_hosts_list",
    hooks = {},
  }

  -- #################################################################

  -- Invocated when the script is loaded
  function script.setup()
    -- Initialize an empty hosts list
    hosts_list = {}

    -- true: this script is enable
    return(true)
  end

  -- #################################################################

  -- The minute callback
  function script.hooks.min(params)
    table.insert(hosts_list, params.entity_info.ip)
  end

  -- #################################################################

  -- Invocated when the script is unloaded
  function script.teardown()
    local data = json.encode({when = os.time(), hosts = hosts_list})

    ntop.httpPost("https://example.com", data)
  end

  -- #################################################################

  return(script)

It's important to note that the `script.setup()` and `script.teardown()` functions
are only executed once per script, whereas the hook functions (`script.hooks.min` in this
case) will be executed once per host.

An easy way to limit the export to the local hosts is to add the `local_hosts = true`
attribute to the script definition.
