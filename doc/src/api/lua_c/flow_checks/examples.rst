.. _ApiFlowChecksExamples target:

Writing Custom Flow Scripts: Guide and Examples
===============================================

This page explains, step by step, how a custom flow script is made
and then shows ready-to-use examples, from the simplest to the more complete ones. Copy an example, change the
values marked in the comments, save it in `/etc/ntopng/custom_checks/flows/` and restart ntopng.

The full list of options and functions is in :ref:`ApiFlowChecks target`.

How a script works
------------------

ntopng looks at every flow (a conversation between a client and a server). For each flow, it asks your script:
*"is there something wrong here?"*. Your script answers by calling `flow.triggerAlert("message")` when it finds a
problem, or by doing nothing when the flow is fine.

A script has two parts:

1. **Which flows to look at** (`filter`): e.g. only Modbus, only port 502, only the hosts of the pool
   *OT Devices*. ntopng applies the filter for you, very quickly, and gives the script only these flows.
2. **What to check** (`check`): a few lines that read the flow (its addresses, ports, bytes, protocol...)
   and decide whether to raise the alert.

The smallest working script is:

.. code:: lua

  return {
    title  = "Telnet in use",
    filter = { srv_port = 23 },

    check = function(flow)
      flow.triggerAlert("Telnet connection to " .. flow.srv())
    end,
  }

Read it as: *"for every flow towards port 23, raise the alert Telnet in use with the message Telnet connection to
<server IP>"*. The filter does all the work, the check only raises the alert.

Lua in five minutes
-------------------

You need very little Lua to write a script. This is all of it:

.. code:: lua

  -- Two dashes start a comment: ntopng ignores the rest of the line.

  -- A variable: a name that holds a value. Always write "local" in front of it.
  local max_bytes = 1000000            -- a number
  local plc_address = "10.0.0.5"        -- a text (string), always in quotes

  -- Join texts with two dots
  local message = "Too much traffic to " .. plc_address

  -- Compare: == (equal), ~= (different, NOT !=), <, >, <=, >=
  -- Combine conditions with: and, or, not
  if flow.bytes() > max_bytes and flow.srv() == plc_address then
    flow.triggerAlert(message)
  end                                   -- every "if" closes with "end"

  -- if / elseif / else
  if flow.srv_port() == 502 then
    -- ...
  elseif flow.srv_port() == 102 then
    -- ...
  else
    -- ...
  end

  -- A list of allowed values (a "set"): the value in square brackets, then "= true"
  local allowed_clients = {
    ["10.0.0.10"] = true,
    ["10.0.0.11"] = true,
  }

  if not allowed_clients[flow.cli()] then  -- true when the client is NOT in the list
    flow.triggerAlert("Client not allowed: " .. flow.cli())
  end

Things to remember:

- Inside `return { ... }` every entry ends with a comma: `title = "...",` `score = 100,` `check = function(flow) ... end,`
- Texts go in double quotes; numbers do not (`502`, not `"502"`).
- `function(flow) ... end`, `if ... then ... end`, `for ... do ... end`: every block closes with `end`.
- Upper and lower case matter: `flow.srv()` works, `flow.SRV()` does not.
- A value that is not there is `nil`. Joining `nil` to a text is an error: use `tostring(value)` when a value may be
  missing, e.g. `"Query: " .. tostring(query)`.

Choosing the flows: the filter
------------------------------

The filter is the most important part: it decides which flows reach the script, and it is evaluated by ntopng at
no cost. Write as narrow a filter as you can.

.. code:: lua

  filter = {
    srv_port = 502,                                -- server port 502
    ip       = { "10.10.0.0/16", "192.168.1.5" },  -- client or server in 10.10.0.0/16, or 192.168.1.5
    pool     = "OT Devices",                       -- client or server in the host pool "OT Devices"
  },

Rules:

- Every field you write must match (it is an AND): the example selects the flows on port 502 **and** with an
  address in the list **and** with a host in the pool.
- A field with a list matches when any of its values does (it is an OR): `srv_port = { 502, 503 }` is port 502 or 503.
- Fields you do not write match every flow. A script without `filter` receives all the flows: avoid it.

Available fields: `cli_ip`, `srv_ip`, `ip`, `cli_port`, `srv_port`, `port`, `l4_proto`, `l7_proto`,
`cli_pool`, `srv_pool`, `pool`. `cli_` means the client, `srv_` the server, no prefix either of them.

`exclude` has the same fields and does the opposite: the flows matching it are skipped. For instance
``exclude = { cli_ip = "10.0.0.250" }`` ignores the flows of a monitoring server.

**Host pools** can be written by name (`"OT Devices"`, exactly as shown in *Pools* > *Host Pools*, upper and
lower case included) or by number (the pool id, e.g. `3`). The hosts that are not in any pool belong to the
`Default` pool (id `0`). The names are read when the script is loaded: after creating or renaming a pool,
disable and enable again *Flow User Check Script* (or restart ntopng) so that the scripts are loaded again. A pool name that
does not exist disables the script, and the ntopng log says so.

When to run: the hooks
----------------------

`hooks` says when ntopng calls the script for a flow:

- `detected`: once, when ntopng recognises the application protocol of the flow (at the start of the flow).
- `periodic`: every few seconds while the flow is active.
- `end`: once, when the flow ends.

Without `hooks` the script runs on all three. Use `detected` to count connections (each flow counts once), and
`periodic` / `end` to check values that grow during the flow (bytes, function codes). A script that calls
`flow.triggerAlert` several times on the same flow does not create duplicate alerts.

Examples
--------

Each example is a complete file. Save it with a name ending in `.lua`, e.g.
`/etc/ntopng/custom_checks/flows/ot_internet.lua`.

Example 1: OT devices talking to the Internet
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The PLCs are in the host pool *OT Devices*: they must only talk inside the plant. Alert when one of them, as a
client, contacts a remote (non local) host.

.. code:: lua

  return {
    title  = "OT device contacts the Internet",
    score  = 100,
    hooks  = { "detected" },
    filter = { cli_pool = "OT Devices" },      -- change it to the name of your pool

    check = function(flow)
      -- "local@remote": local client, remote server
      if flow.direction() == "local@remote" then
        flow.triggerAlert("OT device " .. flow.cli() .. " contacted " .. flow.srv() .. ":" .. flow.srv_port())
      end
    end,
  }


Example 2: only allowed clients may talk to the PLCs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The PLCs are in the pool *PLC*, and only the two engineering workstations may connect to them.

.. code:: lua

  -- The workstations allowed to connect to the PLCs
  local ALLOWED_CLIENTS = {
    ["10.0.0.10"] = true,
    ["10.0.0.11"] = true,
  }

  return {
    title  = "Unauthorised access to PLC",
    score  = 150,
    hooks  = { "detected" },
    filter = { srv_pool = "PLC" },

    check = function(flow)
      if not ALLOWED_CLIENTS[flow.cli()] then
        flow.triggerAlert(flow.cli() .. " connected to PLC " .. flow.srv() .. " on port " .. flow.srv_port())
      end
    end,
  }


Counting over time: counter
---------------------------

Many detections are "too many times in a while": too many connections per minute, a command repeated too often.
A single flow does not know about the other flows, so every script receives a ready-made helper, `counter`,
that keeps counts across flows. Nothing to install or `require`: it is always there.

- | **counter.inc(key, seconds [, amount])**
  | Adds `amount` (default 1) to the counter called `key` and returns its new value. The counter starts from 0
    and is cleared `seconds` after its first `inc` (default 60): then the count starts again from 0.

- | **counter.get(key)**
  | The current value of `key`, without changing it (0 when it was never used or has been cleared).

- | **counter.reset(key)**
  | Clears `key` now.

The `key` is a text you choose, and decides *what* is counted. Build it from the flow:

.. code:: lua

  counter.inc(flow.cli(), 60)                    -- per client, in 1 minute
  counter.inc(flow.srv(), 3600)                  -- per server, in 1 hour
  counter.inc(flow.cli() .. ">" .. flow.srv(), 60) -- per client-server pair, in 1 minute
  counter.inc(flow.srv() .. "/fc65", 60, 10)     -- add 10 to the "function code 65 on this server" count

Good to know:

- The time window is fixed, not sliding: with 60 seconds, a count that starts at 10:00:20 is cleared at
  10:01:20.
- Each script has its own counters: two scripts using the same key do not see each other's counts. The counters
  are also kept per interface, and they are cleared when the scripts are loaded again.
- Use the hook `detected` when counting flows (each flow is counted once). The installed example
  `modbus_function_code_rate.lua` shows how to count the Modbus function codes of all the flows of a PLC.

Example 3: too many connections per minute
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Alert when a client opens more than 30 Modbus connections in one minute (a scan or a misbehaving HMI).
The key is the client address, so each client has its own counter. The hook is `detected`, so that each flow is
counted once.

.. code:: lua

  local MAX_CONNECTIONS_PER_MINUTE = 30

  return {
    title  = "Modbus connection burst",
    hooks  = { "detected" },
    filter = { srv_port = 502, l4_proto = "TCP" },

    check = function(flow)
      local connections = counter.inc(flow.cli(), 60)

      if connections > MAX_CONNECTIONS_PER_MINUTE then
        flow.triggerAlert(flow.cli() .. " opened " .. connections .. " Modbus connections in the last minute")
      end
    end,
  }


OT protocols
------------

In a typical OT installation nProbe analyses the traffic of the plant and sends the flows to ntopng, with the
information of the OT protocols. A script reads it in two ways:

- `flow.ot()`: the OT protocols known to ntopng (Modbus, S7Comm, PROFINET, IEC 60870-5-104), always with the
  same structure, both for the flows sent by nProbe and for the traffic captured by ntopng.
- `flow.json_info()`: any other field nProbe sends with the flow, e.g. the fields that an nDPI plugin adds to an
  OT protocol on the nProbe side (see Example 6).

This is what `flow.ot()` returns for a Modbus flow (the numbers are the totals since the flow started):

.. code:: lua

  {
    modbus = {
      function_codes             = { ["3"] = 20, ["65"] = 150 },  -- function code -> number of uses
      function_codes_transitions = { ["3,65"] = 10 },             -- "from,to" -> number of times
      registers                  = { ["100"] = 12, ["40001"] = 3 }, -- register -> number of uses
      num_exceptions             = 7,                             -- exceptions (errors) returned
    }
  }

S7Comm (`flow.ot().s7comm`) has `function_codes`, `function_codes_transitions` and `num_exceptions`; PROFINET
(`flow.ot().profinet`) also has `operations` (requests, responses ok and responses with errors per operation).
A protocol that is not in the flow is `nil`: always check it, as in the examples below.

.. warning::

  The function codes, transitions and registers are **texts in quotes**: write ``function_codes["65"]``.
  ``function_codes[65]`` (without quotes) is always `nil`, so the script never raises the alert.

The values grow while the flow is active: use the hooks `periodic` and `end`, so the script sees the updated
values. The same alert is not repeated on the same flow.

Example 4: too many Modbus exceptions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Alert when a PLC returns more than 5 exceptions in a flow: a client is sending wrong commands, or the PLC is
failing.

.. code:: lua

  local MAX_EXCEPTIONS = 5

  return {
    title  = "Too many Modbus exceptions",
    score  = 80,
    hooks  = { "periodic", "end" },
    filter = { l7_proto = "Modbus", srv_pool = "PLC" },

    check = function(flow)
      local modbus = flow.ot().modbus
      if not modbus then return end        -- no Modbus information (yet)

      if modbus.num_exceptions > MAX_EXCEPTIONS then
        flow.triggerAlert(modbus.num_exceptions .. " Modbus exceptions from " .. flow.srv())
      end
    end,
  }


Example 5: a function code used too much, or one that must never be used
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Two rules in one script: some Modbus function codes are allowed only up to a number of uses per flow, others
must never be seen.

.. code:: lua

  -- Function code (in quotes) -> maximum number of uses in a flow
  local MAX_USES = {
    ["6"]  = 50,     -- Write Single Register
    ["16"] = 20,     -- Write Multiple Registers
  }

  -- Function codes that must never be used
  local FORBIDDEN = {
    ["8"]  = "Diagnostics",
    ["65"] = "vendor command 65",
  }

  return {
    title  = "Modbus function code not allowed",
    score  = 120,
    hooks  = { "periodic", "end" },
    filter = { l7_proto = "Modbus" },

    check = function(flow)
      local modbus = flow.ot().modbus
      if not modbus then return end

      for code, uses in pairs(modbus.function_codes) do
        if FORBIDDEN[code] then
          flow.triggerAlert("Forbidden function code " .. code .. " (" .. FORBIDDEN[code] .. ") sent to " .. flow.srv())
          return
        end

        if MAX_USES[code] and uses > MAX_USES[code] then
          flow.triggerAlert("Function code " .. code .. " used " .. uses .. " times (max " .. MAX_USES[code] .. ")")
          return
        end
      end
    end,
  }

S7Comm works the same way: use ``flow.ot().s7comm`` and ``filter = { l7_proto = "S7Comm" }``. For instance the S7
function codes ``"40"`` (PLC Control) and ``"41"`` (PLC Stop) start and stop the PLC program and, outside
maintenance, must never be seen.


Example 6: fields added by nProbe plugins
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

When an nProbe plugin (or an nDPI plugin on the nProbe side) adds fields to an OT protocol, the script reads them
with `flow.json_info()`, by the name nProbe gives them. The field names depend on the plugin: to find them, use
this script once, read the names in the ntopng log, then delete it.

.. code:: lua

  return {
    title  = "Show the probe fields",
    hooks  = { "end" },
    filter = { srv_port = 502 },           -- the flows you are interested in

    check = function(flow)
      for name, value in pairs(flow.json_info()) do
        print(name .. " = " .. tostring(value))
      end
    end,
  }

The log shows lines such as `OT_SETPOINT = 812`. Then check the field: `tonumber` turns it into a number (the
probe may send numbers as texts), and is `nil` when the field is missing.

.. code:: lua

  local SETPOINT_MIN, SETPOINT_MAX = 0, 500
  local ALLOWED_COMMANDS = { [1] = true, [2] = true, [7] = true }

  return {
    title  = "OT value out of range",
    score  = 120,
    hooks  = { "periodic", "end" },
    filter = { srv_pool = "PLC" },

    check = function(flow)
      local info = flow.json_info()
      local setpoint = tonumber(info["OT_SETPOINT"])   -- the names printed by the script above
      local command = tonumber(info["OT_CMD"])

      if setpoint and (setpoint < SETPOINT_MIN or setpoint > SETPOINT_MAX) then
        flow.triggerAlert("Setpoint " .. setpoint .. " out of range [" .. SETPOINT_MIN .. ", " .. SETPOINT_MAX .. "] on " .. flow.srv())
      elseif command and not ALLOWED_COMMANDS[command] then
        flow.triggerAlert("Unexpected command " .. command .. " to " .. flow.srv())
      end
    end,
  }

The installed examples `proprietary_protocol_range.lua` and `modbus_function_code_rate.lua` (Modbus function
codes per minute, over all the flows of a PLC) are in `scripts/callbacks/checks/flows/examples/` under the ntopng
installation directory.


Testing a script
----------------

1. Save the script in `/etc/ntopng/custom_checks/flows/` and restart ntopng (or disable and enable again *Flow User Check Script*).
   Do the same after every change to a script: scripts are read only when they are loaded.
2. Look at the ntopng log (e.g. `journalctl -u ntopng`): you should see
   `Loaded custom flow script <file> [title: <title>] on <interface>`. If the script has a mistake, the log says
   why it was disabled, e.g. `unknown key 'filtr'`, `unknown host pool 'OT devices'`, or the line of a Lua error.
3. While writing, add `print(...)` lines to see what the script receives, e.g. ``print(flow.cli(), flow.srv_port())``:
   the output goes to the ntopng log. Remove them when the script works, as they slow ntopng down.
4. Generate the traffic and open the Alerts Explorer, *Flow* tab, filter *Custom Script* = the title of your script.

Common mistakes:

- **Nothing happens**: the filter is too narrow (wrong port, wrong pool name, pool name with different upper/lower
  case), or the *Flow User Check Script* check is not enabled.
- **attempt to concatenate a nil value**: a value joined with `..` is missing; use `tostring(value)` or check it
  with `if value then ... end` first.
- **'=' expected near ...** or **'}' expected near ...**: a comma is missing between two entries of the table.
- **attempt to call a nil value (field ...)**: a function name is misspelled, e.g. `flow.server()` instead of
  `flow.srv()`.
