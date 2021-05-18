
Creating Alerts
===============

Ntopng has the ability to create alerts for hosts, flows, and other network elements. Alerts for flows and hosts are created inside the C++ core of ntopng for performance.  This section describes how to create alerts for hosts and flows. Alerts for other network elements are created by means of plugins (add_ref).

Callbacks
----------

Alerts are created inside callbacks. Callbacks are chunks of code executed by ntopng. Callbacks are implemented as C++ classes with a predefined interface.

Callback classes interface are declared in classes include/FlowCallback.h and  include/HostCallback.h for flow and host callbacks, respectively. Those classes must be used as base classes when implementing callbacks:

  - Every host callback implemented must inherit from HostCallback
  - Every flow callback implemented must inherit from FlowCallback

Classes are implemented with two files, namely a .h file with the class declaration, and a .cpp file with the class definition:

  - Host callback declarations (.h files) are under :code:`include/host_callbacks`. Host callback definitions (.cpp) files are under :code:`src/host_callbacks`.
  - Flow callback declarations (.h files) are under :code:`include/flow_callbacks`. Flow callback definitions (.cpp) files are under :code:`src/host_callbacks`.

Callbacks execution for hosts consists in ntopng calling:

-  HostCallback::periodicUpdate approximately every 60 seconds

Every host callback, when subclassing HostCallback, must override periodicUpdate to implement the desired callback behavior.

Callbacks execution for flows consists in ntopng calling for every flow:

- FlowCallback::protocolDetected as soon as the Layer-7 is detected
- FlowCallback::periodicUpdate approximately every 300 seconds only for flows with a minimum duration of 300 seconds
- FlowCallback::flowEnd as soon as the flow ends, i.e., when a TCP session is closed or when an UDP flow timeouts

Every flow callback, when subclassing FlowCallback, must override one or more of the methods above to implement the desired callback behavior.

Callback Configuration
-----------------------

Callbacks can be configured from the ntopng Web UI. Configuration can be used to set a threshold used by the callback to decide if it is time to create an alert. Similarly, configuration can be used to skip certain IP addresses when executing callbacks.

Callback configuration is done inside small Lua files located in:

- scripts/lua/modules/callback_definitions/flow/ for flow callbacks
- scripts/lua/modules/callback_definitions/host for host callbacks

These files, documented here (add ref) are used to:

- Show labels and configuration in the UI
- Pass the configuration to the callback classes


Alerts
------

Callbacks create alerts as part of their implementation. A callback, during its execution, can detect a certain condition (e.g., an anomaly) for which it decides to create an alert. When the callback decides to create an alert, it informs ntopng by passing it a reference to the alert.

Programmatically, alerts are implemented with C++ classes.

Alert classes interface are declared in classes include/FlowAlert.h and  include/HostAlert.h for flow and host alerts, respectively. Those classes must be used as base classes when implementing alerts:

- Every host alert implemented must inherit from HostAlert
- Every flow alert implemented must inherit from FlowAlert


Examples
----------

Files .h and .cpp must have the same name. For example, the flow callback WebMining in charge of creating alerts for flows performing cryptocurrency mining is implemented in files:

- ./include/flow_callbacks/WebMining.h
- ./src/flow_callbacks/WebMining.cpp

Similarly, the host callback SYNScan in charge of creating alerts for hosts that are SYN scanners or scan victims is implemented in files:

- ./include/host_callbacks/SYNScan.h
- ./src/host_callbacks/SYNScan.cpp


Callbacks execution is:

- Periodic for hosts
- Event-based for flows

