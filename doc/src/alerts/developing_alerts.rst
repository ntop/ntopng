.. _DevelopingAlerts:

Developing Alerts
#################

ntopng has the ability to create alerts for flows, hosts, and other network elements. Alerts for flows and hosts are created inside the C++ core of ntopng for performance. This section describes how to create alerts for hosts and flows. Alerts for other network elements are created by means of scripts (:ref:`Script Structure`).

Alerts are created inside checks. This section starts with a description of checks, and then moves to the alerts. The interplay between alerts and checks is presented, along with examples with the aim of giving a comprehensive overview of all the components at play.  The section ends with handy checklists that can be used as reference when developing alerts.

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
------------------

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
----------------------

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

Checks use :code:`triggerAlertAsync` or :code:`triggerAlertSync` to tell ntopng to create an asyncronous alert. The first method is an asyncronous call, faster, but can cause the alert JSON to be generated after the call. The FlowCheck should implement the buildAlert() method which is called in the predominant check to actually build the FlowAlert object.
The second method is a syncrhonous call, more expensive, but causes the alert (FlowAlert) to be immediately enqueued to all recipients.
This call is faster  a syncronous call but  . Indeed, The actual alert creation is triggered from the flow check with the call :code:`f->triggerAlertAsync` or :code:`f->triggerAlertSync`. This call tells ntopng to create an alert identified with :code:`BlacklistedFlowAlert::getClassType()` on the flow instance pointed by :code:`f`.

Creating Host Alerts
--------------------

Alert classes are instantiated inside host checks.

Checks use :code:`triggerAlert` to tell ntopng to create an alert with an engaged status, and need to be released. 
Indeed, The actual alert creation is triggered from the host check with the call :code:`h->triggerAlert` that wants a pointer to the host alert instance as parameter. This call tells ntopng to create an alert on the host instance pointed by :code:`h`.
Is it even possible to use another method, :code:`storeAlert`, that once triggered is immediately emitted.

Symple Host Alert example
======

In this section we will guide you through the implementation of a new host alert that trigger when an host see more than a specified number of flow with http protocol.
The purpouse of this guide is to show which passages are needed in order to add an alert, for an host. Indeed the Flow alert implementation need the add of similar files inside the corresponding flow subdirectory, as specified in the above sections. 

Alert Definition
--------------------

Let's begin by creating al the files of the alert.
 
Under :code:`scripts/lua/modules/alert_definitions/host/` create a new file, in this case :code:`host_alert_http_contacts`

.. code:: Lua
	local host_alert_keys = require "host_alert_keys"

	local json = require("dkjson")
	local alert_creators = require "alert_creators"

	local classes = require "classes"
	local alert = require "alert"

	local host_alert_http_contacts = classes.class(alert)

	host_alert_http_contacts.meta = {
	alert_key = host_alert_keys.host_alert_http_contacts,
	i18n_title = "alerts_dashboard.http_contacts_title",
	icon = "fas fa-fw fa-life-ring",
	}

	-- @brief Prepare an alert table used to generate the alert
	-- @param one_param The first alert param
	-- @param another_param The second alert param
	-- @return A table with the alert built
	function host_alert_http_contacts:init(metric, value, operator, threshold)
	-- Call the parent constructor
	self.super:init()

	self.alert_type_params = alert_creators.createThresholdCross(metric, value, operator, threshold)
	end

	-- @brief Format an alert into a human-readable string
	-- @param ifid The integer interface id of the generated alert
	-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
	-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
	-- @return A human-readable string
	function host_alert_http_contacts.format(ifid, alert, alert_type_params)
	local alert_consts = require("alert_consts")
	local entity = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
	local value = string.format("%u", math.ceil(alert_type_params.num_flows or 0))
	
	return i18n("alerts_dashboard.http_contacts_message", {
		entity = entity,
		value = value,
		threshold = alert_type_params.threshold or 0,
	})
	end

	return host_alert_http_contacts
This example contains all the information needed in order to show the alert on the corresponding page of the ntopng GUI. Function :code:`host_alert_http_contacts.format` takes care of creating the respective message that will be displayed.

As seen before, we need to specify an unique alert key both in Lua and C++ files,

Next thing to do is to define the alert key of the new alert, inside :code:`scripts/lua/modules/alert_key/host_alert_keys.lua`

.. code:: Lua 
	local host_alert_keys = {
	[...]
	host_alert_http_contacts               = 30,
	}

Same for :code:`HostAlertTypeEnum` inside :code:`include/ntop_typedefs.h`.

.. code:: C++
	typedef enum {
	[...]
	host_alert_http_counts = 30
	[...]
	} HostAlertTypeEnum; 


Now it's time to declare the corresponding C++ class. Under :code:`include/host_alerts/` create the header file :code:`HTTPContactsAlert.h`

.. code:: C++
	#ifndef _HTTP_CONTACTS_ALERT_H_
	#define _HTTP_CONTACTS_ALERT_H_

	#include "ntop_includes.h"

	class HTTPContactsAlert : public HostAlert {
	private:
	u_int16_t num_http_flows;
	u_int64_t threshold;

	ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);

	public:
	static HostAlertType getClassType() {
		return {host_alert_http_contacts, alert_category_network};
	}

	HTTPContactsAlert(HostCheck* c, Host* f, risk_percentage cli_pctg,
							u_int16_t _num_http_flows, u_int64_t _threshold);
	~HTTPContactsAlert(){};

	HostAlertType getAlertType() const { return getClassType(); }
	u_int8_t getAlertScore() const { return SCORE_LEVEL_WARNING; };
	};

	#endif /* _HTTP_CONTACTS_ALERT_H_ */

We need to reference this file inside include/host_alerts_includes.h in order to be linked with the rest of files.

.. code:: C++
	[...]
	#include "host_alerts/HTTPContactsAlert.h"

We can now define the effective C++ class, under :code:`src/host_alerts/` create a new file :code:`HTTPContactsAlert.cpp`

.. code:: C++
	#include "host_alerts_includes.h"

	HTTPContactsAlert::HTTPContactsAlert(HostCheck* c, Host* f,
												risk_percentage cli_pctg,
												u_int16_t _num_http_flows, u_int64_t _threshold)
		: HostAlert(c, f, cli_pctg) {
	num_http_flows = _num_http_flows;
	threshold = _threshold;
	};

	ndpi_serializer* HTTPContactsAlert::getAlertJSON(
		ndpi_serializer* serializer) {
	if (serializer == NULL) return NULL;

	ndpi_serialize_string_uint32(serializer, "num_flows", num_http_flows);
	ndpi_serialize_string_uint64(serializer, "threshold", threshold);

	return serializer;
	}

The :code:`getAlertJSON()` method is used to store the information that will be displayed, in our case the number of http flows seen by an host and the given number that the host must not exceed.

Check Definition
--------------------

Once the alert definition is completed, it's time to move on the check definition, the core part that is responsible for triggering the alarm.

As we have seen for the alert, first of all we need to create the relative Lua script. This time under :code:`scripts/lua/modules/check_definitions/host/` create a new file, :code:`http_contacts.lua`

.. code:: Lua
	local checks = require("checks")
	local host_alert_keys = require "host_alert_keys"
	local alert_consts = require("alert_consts")

	local http_contacts = {
	-- Script category
	category = checks.check_categories.network,
	severity = alert_consts.get_printable_severities().warning,

	default_enabled = false,
	alert_id = host_alert_keys.host_alert_http_contacts,

	default_value = {
		operator = "gt",
		threashold = 128,
	},
	
	gui = {
		i18n_title = "alerts_dashboard.http_contacts_title",
		i18n_description = "alerts_dashboard.http_contacts_description",
		i18n_field_unit = checks.field_units.http_flow,
		input_builder = "threshold_cross",
		field_max = 65535,
		field_min = 1,
		field_operator = "gt";
	}
	}

	return http_contacts

The default_value section as well as all the field variables, are responsible to get the number that we want to give to this alert. For the alerts that don't need such parameter, that part can be omitted.

For the C++ part, create the header file in :code:`include/host_checks/` :code:`HTTPContacts.h`

.. code:: C++
	#ifndef _HTTP_CONTACTS_H_
	#define _HTTP_CONTACTS_H_

	#include "ntop_includes.h"

	class HTTPContacts : public HostCheck {
	protected:
	u_int64_t threshold;

	public:
	HTTPContacts();
	~HTTPContacts(){};

	HTTPContactsAlert *allocAlert(HostCheck *c, Host *h,
										risk_percentage cli_pctg,
										u_int16_t num_http_flows, u_int64_t threshold) {
		return new HTTPContactsAlert(c, h, cli_pctg, num_http_flows, threshold);
	};

	bool loadConfiguration(json_object *config);
	void periodicUpdate(Host *h, HostAlert *engaged_alert);

	HostCheckID getID() const { return host_check_http_cpmtacts; }
	std::string getName() const { return (std::string("http_contacts")); }
	};

	#endif

Add the reference to that file inside :code:`include/host_checks_includes.h`

.. code:: C++
	#ifndef _HOST_CHECKS_INCLUDES_H_
	#define _HOST_CHECKS_INCLUDES_H_
	[...]
	#include "host_checks/HTTPContacts.h"
	[...]


In the same file of HostAlertTypeEnum, :code:`include/ntop_typedefs.h`, modify the HostCheckID Enum

.. code:: C++
	typedef enum {
	host_check_http_replies_requests_ratio = 0,
	[...]
	host_check_http_contacts,
	[...]

	} HostCheckID;

Now, inside :code:`src/host_checks/`, create :code:`HTTPContacts.cpp`

.. code:: C++
	#include "ntop_includes.h"
	#include "host_checks_includes.h"

	/* ***************************************************** */

	HTTPContacts::HTTPContacts()
		: HostCheck(ntopng_edition_community, false /* All interfaces */,
					false /* Don't exclude for nEdge */,
					false /* NOT only for nEdge */){};

	/* ***************************************************** */

	void HTTPContacts::periodicUpdate(Host *h, HostAlert *engaged_alert) {
	HostAlert *alert = engaged_alert;
	u_int8_t num_http_flows = 0;

	num_http_flows = h->getNumHttpFlows();

	if (num_http_flows > threshold) {
		if (!alert)
		alert =
			allocAlert(this, h, CLIENT_FAIR_RISK_PERCENTAGE, num_http_flows, threshold);
		if (alert) {
		h->triggerAlert(alert);
		h->resetNumHttpFlows();
		} 
	}
	}

	bool HTTPContacts::loadConfiguration(json_object *config) {
	json_object *json_threshold;

	HostCheck::loadConfiguration(config); /* Parse parameters in common */

	if (json_object_object_get_ex(config, "threshold", &json_threshold))
		threshold = json_object_get_int64(json_threshold);
	return (true);
	}

We need to tell to ntopng to instantiate the check class, to do so we need to modify :code:`src/HostChecksLoader.cpp`

.. code:: C++
	void HostChecksLoader::registerChecks() {
	HostCheck *fcb;

	if ((fcb = new CountriesContacts()))   registerCheck(fcb);
	[...]
	if ((fcb = new HTTPContacts()))        registerCheck(fcb);
	[...]
	}

These are the basic steps needed and must be replicated for all host, but even flow, to define a new host alert.
What we can add now is a variable to be avaiable during the periodic update that store how many http flows an host have seen until that time.
To do so we can modify the Host class adding a variable and a getter.  

In :code:`/inlcude/Host.h` add the variable as well as a function to get it and ones to reset it.

.. code:: C++
	class Host : public GenericHashEntry,
				public Score,
				public HostChecksStatus,
			public HostAlertableEntity /* Eventually move to LocalHost */ {
	protected:
	[...]
	u_int32_t num_http_flows;
	[...]
	puiblic:
	[...]
	inline u_int32_t getNumHttpFlows() { return (num_http_flows); };
	inline void resetNumHttpFlows() { num_http_flows = 0; };
	}


Now we need to update the variable every time a new http connection has been seen. To do so modify :code:`/src/Host.cpp`

.. code:: C++
	void Host::initialize(Mac *_mac, int32_t _iface_idx,
				u_int16_t _vlanId,
						u_int16_t observation_point_id) {
	if (_vlanId == (u_int16_t)-1) _vlanId = 0;
	num_http_flows = 0;
	[...]
	}
	[...]
	void Host::incStats(u_int32_t when, u_int8_t l4_proto, u_int ndpi_proto,
						ndpi_protocol_category_t ndpi_category,
						custom_app_t custom_app, u_int64_t sent_packets,
						u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
						u_int64_t rcvd_packets, u_int64_t rcvd_bytes,
						u_int64_t rcvd_goodput_bytes, bool peer_is_unicast) {
	// http has the protocol id equal to 7
	if(ndpi_proto == 7) num_http_flows++;
	[...]
	}

Formatting the output
--------------------

One last thing we can do is to modify the locales in order to visualize both the check enable section and the alert launched in a readable format. 

Inside scripts/locales/en.lua we need to search for the `alerts_dashboard` section and add 

.. code:: Lua
	[...]
	["alerts_dashboard"] = {
		...
		["http_contacts_description"] = "DESIRED CHECK DESCRIPTION",
		["http_contacts_title"] = "DESIRED ALERT TITLES",
		["http_contacts_message"] = "DESIRED MESSAGE TO DISPLAY",
	},
	[...]
