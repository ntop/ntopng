Simple Host Alert Example
=========================

In this section we will guide you through the implementation of a new host alert that trigger when an host see more than a specified number of flow with http protocol, we will call it :code:`HTTPContactsAlert`.
The purpouse of this guide is to show which passages are needed in order to add an alert, for an host. Indeed the Flow alert implementation need the add of similar files inside the corresponding flow subdirectory, as specified in the above sections. 

Alert Definition
----------------

In order to create the alert, we need to create and modify a few files, they include:

- New files to be created:

	- :code:`host_alert_http_contacts.lua` under :code:`scripts/lua/modules/alert_definitions/host/`, this file is responsable of rendering the alert in the GUI
	- :code:`HTTPContactsAlert.h` under :code:`include/host_alerts/`, this is the header for the class representing the alert 
	- :code:`HTTPContactsAlert.cpp` under :code:`src/host_alerts/`, this is the implementation of the class representing the alert 

- Existing files to be modified:

	- :code:`scripts/lua/modules/alert_key/host_alert_keys.lua` and :code:`include/ntop_typedefs.h`, we have to place the unique alert key in both files. The number representing the alert identifier must be unused before and the same in the two files.
	- :code:`include/host_alerts_includes.h`, where we need to add the include for the new alert's header file
 
Let's see what is the content of each file, step by step.

Under :code:`scripts/lua/modules/alert_definitions/host/` create a new file, in this case :code:`host_alert_http_contacts.lua`

.. code:: lua

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

As seen before, we need to specify an unique alert key both in Lua and C++ files.

Next thing to do is to define the alert key of the new alert, inside :code:`scripts/lua/modules/alert_key/host_alert_keys.lua`

.. code:: lua

	local host_alert_keys = {
	[...]
	host_alert_http_contacts               = 30,
	}

Same for :code:`HostAlertTypeEnum` inside :code:`include/ntop_typedefs.h`.

.. code:: C

	typedef enum {
	[...]
	host_alert_http_counts = 30
	[...]
	} HostAlertTypeEnum; 

Now it's time to declare the corresponding C++ class. Under :code:`include/host_alerts/` create the header file :code:`HTTPContactsAlert.h`

.. code:: C

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

We need to reference this file inside :code:`include/host_alerts_includes.h` in order to be linked with the rest of files.

.. code:: C

	[...]
	#include "host_alerts/HTTPContactsAlert.h"

We can now define the effective C++ class, under :code:`src/host_alerts/` create a new file :code:`HTTPContactsAlert.cpp`

.. code:: C

	#include "host_alerts_includes.h"

	HTTPContactsAlert::HTTPContactsAlert(HostCheck* c, Host* f,
		risk_percentage cli_pctg, u_int16_t _num_http_flows, u_int64_t _threshold)
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

Let's give a brief introduction of what we are going to do:

- New files to be created:

	- :code:`http_contacts.lua` under :code:`scripts/lua/modules/check_definitions/host/`, this file is responsable for the visualization of the check enabler on the GUI.
	- :code:`HTTPContacts.h` under :code:`include/host_checks/, this is the header for the class representing the check 
	- :code:`HTTPContacts.cpp` under :code:`src/host_checks/`, this is the implementation of the class representing the check 

- Existing files to be modified:

	- :code:`include/host_checks_includes.h` to include the new check.
	- :code:`include/ntop_typedefs.h`, in this file we have to specify the identifier of the new check.
	- specify the constructor of the new check class inside :code:`src/HostChecksLoader.cpp` 

As we have seen for the alert, first of all we need to create the relative Lua script. This time under :code:`scripts/lua/modules/check_definitions/host/` create a new file, :code:`http_contacts.lua`

.. code:: lua

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

.. code:: C

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

.. code:: C

	#ifndef _HOST_CHECKS_INCLUDES_H_
	#define _HOST_CHECKS_INCLUDES_H_
	[...]
	#include "host_checks/HTTPContacts.h"
	[...]


In the same file of :code:`HostAlertTypeEnum`, :code:`include/ntop_typedefs.h`, modify the HostCheckID Enum:

.. code:: C

	typedef enum {
	host_check_http_contacts,
	} HostCheckID;

Now, inside :code:`src/host_checks/`, create :code:`HTTPContacts.cpp`

.. code:: C

	#include "ntop_includes.h"
	#include "host_checks_includes.h"

	HTTPContacts::HTTPContacts()
		: HostCheck(ntopng_edition_community, false /* All interfaces */,
					false /* Don't exclude for nEdge */,
					false /* NOT only for nEdge */){};

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

	HostCheck::loadConfiguration(config);

	if (json_object_object_get_ex(config, "threshold", &json_threshold))
		threshold = json_object_get_int64(json_threshold);
	return (true);
	}

We need to tell to ntopng to instantiate the check class, to do so we need to modify :code:`src/HostChecksLoader.cpp`

.. code:: C

	void HostChecksLoader::registerChecks() {
	HostCheck *fcb;

	if ((fcb = new CountriesContacts()))   registerCheck(fcb);
	[...]
	if ((fcb = new HTTPContacts()))        registerCheck(fcb);
	[...]
	}

These are the basic steps needed and must be replicated every time we want to add a new alert, both for host or flow.
What we can add now is a variable to be avaiable during the periodic update that store how many http flows an host have seen until that time.
To do so we can modify the Host class adding a variable and a getter.  

In :code:`/inlcude/Host.h` add the variable as well as a function to get it and ones to reset it.

.. code:: C

	class Host : public GenericHashEntry,
				public Score,
				public HostChecksStatus,
			public HostAlertableEntity {
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

.. code:: C

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
----------------------

One last thing we can do is to modify the locales in order to visualize both the check enable section and the alert launched in a readable format. 
Inside scripts/locales/en.lua we need to search for the `alerts_dashboard` section, then the localization strings we dedined in the alert and check definitions, and add the localized strings.

.. code:: lua

	[...]
	["alerts_dashboard"] = {
		...
		["http_contacts_description"] = "DESIRED CHECK DESCRIPTION",
		["http_contacts_title"] = "DESIRED ALERT TITLES",
		["http_contacts_message"] = "DESIRED MESSAGE TO DISPLAY",
	},
	[...]
