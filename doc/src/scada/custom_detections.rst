.. _CustomDetections:

Custom Detections
=================

Besides the checks built into ntopng, you can add your own detections for OT protocols, for instance:

- a Modbus application that uses custom function codes: alert when they are requested too often, or when a
  client sends commands it should not send;
- a proprietary protocol over TCP/IP: alert when a device is contacted too often, or when a field of the protocol
  carries a value outside the allowed range.

A custom detection is a small Lua script: ntopng gives it each flow you select (by IP address, port, layer 4 and
application protocol) and the script decides whether to raise an alert. You do not need to change or rebuild
ntopng: scripts are added and removed as files.

Where the data comes from
-------------------------

- **Protocols analysed by ntopng** (Modbus, S7Comm, PROFINET, IEC 60870-5-104): the script receives the function
  codes, their transitions, the registers and the exceptions of the flow, as shown in the flow details.
- **Proprietary protocols**: ntopng does not see the content of collected flows. An nProbe plugin extracts the
  relevant bytes of the protocol (commands, values) and sends them with the flow; the script receives them as
  flow fields.

How to use it
-------------

1. Enable *Flow User Check Script* in *Settings* > *Behavioural Checks* > *Flows*.
2. Copy your scripts to :code:`/etc/ntopng/custom_checks/flows/`. Two examples, one for Modbus custom function
   codes and one for a proprietary protocol, are installed in :code:`scripts/callbacks/checks/flows/examples/`
   under the ntopng installation directory: copy them there and adapt them.
3. Restart ntopng (or save the behavioural checks configuration again).

The ntopng log lists every script loaded and every script discarded, with the reason (for instance a misspelled
option or an invalid IP address).

Alerts
------

Each script has a title, e.g. *Modbus custom function code rate*. When a script detects an issue, the flow gets a
*Custom Script* alert that reports the title of the script and its message. If several scripts detect an issue on
the same flow, the flow has one alert with all their titles and messages.

To see the alerts of one script, open the Alerts Explorer, *Flow* tab, and add the *Custom Script* filter with the
title of the script (*=*), or with a part of it (*contains*). The filter also finds flows whose main alert is a
different one. Use titles made of letters, numbers and spaces: quotes and the :code:`<` :code:`>` characters
cannot be used in the filter.

Writing a script
----------------

The script format, the flow filters and the available functions are described in :ref:`ApiFlowChecks target`.
