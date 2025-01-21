.. _FlowHostAlerts:

Flow/Host Alerts
################

Checks
======

Alerts are created inside checks. Checks are chunks of code executed by ntopng. Checks are implemented as C++ classes with a predefined interface.

Check interfaces are declared in classes:

- :code:`include/FlowCheck.h` for flows
- :code:`include/HostCheck.h` for hosts

Those classes must be used as base classes when implementing checks:

  - Every host check implemented must inherit from :code:`HostCheck`
  - Every flow check implemented must inherit from :code:`FlowCheck`

Classes are implemented with two files, namely a :code:`.h` file with the class declaration, and a :code:`.cpp` file with the class definition:

  - Host check declarations (:code:`.h` files) are under :code:`include/host_checks`. Host check definitions (:code:`.cpp`) files are under :code:`src/host_checks`.
  - Flow check declarations (:code:`.h` files) are under :code:`include/flow_checks`. Flow check definitions (:code:`.cpp`) files are under :code:`src/host_checks`.

Check Execution
---------------

Checks execution for hosts consists in ntopng calling:

-  :code:`HostCheck::periodicUpdate` approximately every 60 seconds

Every host check, when subclassing :code:`HostCheck`, must override :code:`periodicUpdate` to implement the desired check behavior.

Checks execution for flows consists in ntopng calling for every flow:

- :code:`FlowCheck::protocolDetected` as soon as the Layer-7 is detected
- :code:`FlowCheck::periodicUpdate` approximately every 300 seconds only for flows with a minimum duration of 300 seconds
- :code:`FlowCheck::flowEnd` as soon as the flow ends, i.e., when a TCP session is closed or when an UDP flow timeouts
- :code:`FlowCheck::flowBegin` as soon as the flow is seen for the first time

Every flow check, when subclassing :code:`FlowCheck`, must override one or more of the methods above to implement the desired check behavior.

Check Configuration
-------------------

Checks are configured from the ntopng Web UI. Configuration involves the ability to:

- Turn any check on or off
- Set configuration parameters selectively for every check

A check that is turned off is not executed. Configuration parameters can be used to set a threshold used by the check to decide if it is time to create an alert. Similarly, configuration parameters can be used to indicate a list of IP addresses to exclude when executing checks.

ntopng, to populate the check configuration UI and to properly store the configured check parameters that will be passed to the C++ check class instances, needs to know along with other information:

- Strings (optionally localized) for check names and descriptions
- Type and format of the configuration parameters
- Default parameters, e.g, whether the check is on or off by default

ntopng reads this information from small Lua files located in:

- :code:`scripts/lua/modules/check_definitions/flow/` for flow checks
- :code:`scripts/lua/modules/check_definitions/host` for host checks

These files, documented here (add ref) are mandatory and must be present for a check to be properly executed.

ntopng use names to link check configuration with its C++ class instance. A common :code:`<name>` must be used as:

- The name of the Lua file under :code:`scripts/lua/modules/check_definitions`, e.g., :code:`<name>.lua`
- The string returned by method :code:`getName` in the C++ class file, e.g., :code:`std::string getName() const { return(std::string("<name>")); }`.


Alerts
======

Checks create alerts as part of their implementation. A check, during its execution, can detect a certain condition (e.g., an anomaly) for which it decides to create an alert. When the check decides to create an alert, it informs ntopng by passing a reference to the alert.

Alerts are implemented with C++ classes. Alert interfaces are declared in classes:

- :code:`include/FlowAlert.h` for flows
- :code:`include/HostAlert.h` for hosts

Those classes must be used as base classes when implementing alerts:

- Every host alert implemented must inherit from :code:`HostAlert`
- Every flow alert implemented must inherit from :code:`FlowAlert`

Identifying Alerts
------------------

Alerts are uniquely identified with a key, present both in C++ and Lua. In C++ alert keys are enumerated inside file :code:`ntop_typedefs.h`:

- Enumeration :code:`FlowAlertTypeEnum` defines keys for flow alerts
- Enumeration :code:`HostAlertTypeEnum` defines keys for host alerts

Every C++ alert class must implement :code:`getClassType` to return an enumerated alert key. Every enumerated value must be used by one and only one alert class.

In Lua, alert keys are enumerated inside files:

- :code:`scripts/lua/modules/alert_keys/flow_alert_keys.lua` for flow alerts
- :code:`scripts/lua/modules/alert_keys/host_alert_keys.lua` for host alerts

C++ and Lua files must be synchronized, that is, they must have the same enumerated alert keys. This means using the same enumeration names and numbers, in C++:

.. code:: C

  typedef enum {
  flow_alert_normal                           = 0,
  flow_alert_blacklisted                      = 1,
  flow_alert_blacklisted_country              = 2,
  [...]
  } FlowAlertTypeEnum;

and in Lua:

.. code:: lua

  local flow_alert_keys = {
    flow_alert_normal                          = 0,
    flow_alert_blacklisted                     = 1,
    flow_alert_blacklisted_country             = 2,
    [...]
   }

To implement an alert, an additional alert key must be added to bot C++ and Lua.


Alert Formatting
----------------

Alerts are shown graphically inside the ntopng web UI and are also exported to external recipients. ntopng, to format alerts, needs to know along with other information:

- Unique alert keys
- Strings (optionally localized) for alert names and descriptions
- How to handle parameters inserted into the alert from the C++ classes

ntopng reads this information from small Lua files located in:

- :code:`scripts/lua/modules/alert_definitions/flow/` for flow alerts
- :code:`scripts/lua/modules/alert_definitions/host/` for host alerts

These files are mandatory and must be present for an alert to be properly created and visualized. Each file must return a table containing some metadata, including a unique alert key read from one of the Lua alert keys enumeration files. Each alert key must be returned by one and only one Lua file.


Creating Flow Alerts
--------------------

Alert classes are instantiated inside :code:`buildAlert`, a method that must be implemented by each flow check. This method is called by ntopng to create the alert, when it has been told to do so from a flow check.

Checks use :code:`triggerAlert` to pass ntopng an alert. The first method is an asyncronous call, faster, but can cause the alert JSON to be generated after the call. The FlowCheck should implement the buildAlert() method which is called in the predominant check to actually build the FlowAlert object.
The second method is a syncrhonous call, more expensive, but causes the alert (FlowAlert) to be immediately enqueued to all recipients.

Creating Host Alerts
--------------------

Alert classes are instantiated inside host checks.

Checks use :code:`triggerAlert` to tell ntopng to create an alert with an engaged status, and need to be released. 
Indeed, the actual alert creation is triggered from the host check with the call :code:`h->triggerAlert` that wants a pointer to the host alert instance as parameter. This call tells ntopng to create an alert on the host instance pointed by :code:`h`.
Is it even possible to use another method, :code:`storeAlert`, that once triggered is immediately emitted.

