.. _Policies:

Policies
########

.. note::

  This menu is available for both Network and System Interface.

In the ‘Policies’ entry, various policies and rules can be configured to handle the Network, going from policies regarding Alerts (Checks) to Traffic Profiles.

Here a list of policies that can be configured:

- Access Control List: configurable set of traffic that is allowed on the machine, all the other traffic triggers an alert;
- Allowed Applications: configurable set of policies to determine which applications are acceptable for the specific device type;
- Device/MAC Address Tracking: detect devices (identified with MAC addresses) that connect to a network;
- Network Configuration: configurable set of rules to address Hosts in the local network;
- Traffic Profiles: logical aggregations of traffic, set by the user;

.. toctree::
    :maxdepth: 2

    access_control_list
    allowed_applications
    device_mac_address_tracking
    network_configuration
    traffic_rules
    ../alerts/others/available_alerts
    ../alerts/others/behavioural_checks_exclusion
    traffic_profiles


