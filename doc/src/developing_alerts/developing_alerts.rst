
Creating Alerts
###############

Ntopng has the ability to create alerts for hosts, flows, and other network elements. Alerts for flows and hosts are created inside the C++ core of ntopng for performance.  This section describes how to create alerts for hosts and flows. Alerts for other network elements are created by means of plugins (add_ref).


Callbacks
=========

Alerts are created inside callbacks. Callbacks are chunks of code executed by ntopng. Callbacks are implemented as C++ classes with a predefined interface.

Callback interfaces are declared in classes:

- :code:`include/FlowCallback.h` for flows
- :code:`include/HostCallback.h` for hosts

Those classes must be used as base classes when implementing callbacks:

  - Every host callback implemented must inherit from :code:`HostCallback`
  - Every flow callback implemented must inherit from :code:`FlowCallback`

Classes are implemented with two files, namely a :code:`.h` file with the class declaration, and a :code:`.cpp` file with the class definition:

  - Host callback declarations (:code:`.h` files) are under :code:`include/host_callbacks`. Host callback definitions (:code:`.cpp`) files are under :code:`src/host_callbacks`.
  - Flow callback declarations (:code:`.h` files) are under :code:`include/flow_callbacks`. Flow callback definitions (:code:`.cpp`) files are under :code:`src/host_callbacks`.

Callbacks execution for hosts consists in ntopng calling:

-  :code:`HostCallback::periodicUpdate` approximately every 60 seconds

Every host callback, when subclassing :code:`HostCallback`, must override :code:`periodicUpdate` to implement the desired callback behavior.

Callbacks execution for flows consists in ntopng calling for every flow:

- :code:`FlowCallback::protocolDetected` as soon as the Layer-7 is detected
- :code:`FlowCallback::periodicUpdate` approximately every 300 seconds only for flows with a minimum duration of 300 seconds
- :code:`FlowCallback::flowEnd` as soon as the flow ends, i.e., when a TCP session is closed or when an UDP flow timeouts

Every flow callback, when subclassing :code:`FlowCallback`, must override one or more of the methods above to implement the desired callback behavior.

Callback Configuration
----------------------

Callbacks are configured from the ntopng Web UI. Configuration involves the ability to:

- Turn any callback on or off
- Set configuration parameters selectively for every callback

A callback that is turned off is not executed. Configuration parameters can be used to set a threshold used by the callback to decide if it is time to create an alert. Similarly, configuration parameters can be used to indicate a list of IP addresses to exclude when executing callbacks.

ntopng, to populate the callback configuration UI and to properly store the configured callback parameters that will be passed to the C++ callback class instances, needs to know along with other information:

- Strings (optionally localized) for callback names and descriptions
- Type and format of the configuration parameters
- Default parameters, e.g, whether the callback is on or off by default

ntopng reads this information from small Lua files located in:

- :code:`scripts/lua/modules/callback_definitions/flow/` for flow callbacks
- :code:`scripts/lua/modules/callback_definitions/host` for host callbacks

These files, documented here (add ref) are mandatory and must be present for a callback to be properly executed.

ntopng use names to link callback configuration with its C++ class instance. A common :code:`<name>` must be used as:

- The name of the Lua file, e.g., :code:`scripts/lua/modules/callback_definitions/flow/<name>.lua`
- The string returned by method :code:`getName` in the C++ class file, e.g., :code:`std::string getName() const { return(std::string("<name>")); }`.

Example
-------

The following figure shows the interplay between the various components of a flow callback. :code:`BlacklistedFlow` is used for reference. Full-screen is recommended to properly visualize the figure.

.. figure:: ../img/developing_alerts_callback_structure.png
  :align: center
  :alt: BlacklistedFlow Flow Callback

  BlacklistedFlow Flow Callback


File :code:`BlacklistedFlow.h` *(1)* contains the declaration of class `BlacklistedFlow`, a subclass of :code:`FlowCallback`. The class is defined in :code:`BlacklistedFlow.h` *(2)* that contains class methods implementation.

To have :code:`BlacklistedFlow` compiled, an :code:`#include` directive must be added in file :code:`include/flow_callbacks_includes.h` *(3)*. The directive must contain the path to the class declaration file :code:`BlacklistedFlow.h`.

To have the callback loaded and executed at runtime, :code:`BlacklistedFlow` must be instantiated and added to the ntopng callbacks in file :code:`src/FlowCallbacksLoader.cpp` *(4)*.

Method :code:`protocolDetected` is overridden and implemented in :code:`BlacklistedFlow.cpp` *(5)* so that ntopng will call it for every flow as soon as the Layer-7 application protocol is detected.

Callback configuration UI is populated according to the contents of :code:`scripts/lua/modules/callback_definitions/flow/blacklisted.lua` *(6)*. ntopng is able to link the callback configuration with its C++ class thanks to the name :code:`blacklisted` as highlighted with the arrow starting at *(6)*. Indeed, to have the C++ and the Lua properly linked, the same name is used for:

- The name of the Lua file
- The string returned by method :code:`getName` in the C++ class file


Alerts
======

Callbacks create alerts as part of their implementation. A callback, during its execution, can detect a certain condition (e.g., an anomaly) for which it decides to create an alert. When the callback decides to create an alert, it informs ntopng by passing a reference to the alert.

Alerts are implemented with C++ classes.

Alert interfaces are declared in classes:

- :code:`include/FlowAlert.h` for flows
- :code:`include/HostAlert.h` for hosts

Those classes must be used as base classes when implementing alerts:

- Every host alert implemented must inherit from :code:`HostAlert`
- Every flow alert implemented must inherit from :code:`FlowAlert`

Alert Formatting
----------------

Alerts are shown graphically inside the ntopng web UI and are also exported to external recipients. ntopng, to format alerts, needs to know along with other information:

- Strings (optionally localized) for alert names and descriptions
- How to handle parameters inserted into the alert from the C++ classes

ntopng reads this information from small Lua files located in:

- :code:`scripts/lua/modules/alert_definitions/flow/` for flow alerts
- :code:`scripts/lua/modules/alert_definitions/host` for host alerts

These files are mandatory and must be present for an alert to be properly created and visualized.



Examples
----------

Files .h and .cpp must have the same name. For example, the flow callback WebMining in charge of creating alerts for flows performing cryptocurrency mining is implemented in files:

- :code:`./include/flow_callbacks/WebMining.h`
- :code:`./src/flow_callbacks/WebMining.cpp`

Similarly, the host callback SYNScan in charge of creating alerts for hosts that are SYN scanners or scan victims is implemented in files:

- :code:`./include/host_callbacks/SYNScan.h`
- :code:`./src/host_callbacks/SYNScan.cpp`


Callbacks execution is:

- Periodic for hosts
- Event-based for flows

