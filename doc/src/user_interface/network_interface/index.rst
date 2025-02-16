Network Interface
#################

This Web Interface is used to monitor the status of a Network Interface; there can be different types of network interfaces, see this `section`_ for more info.

.. figure:: ../../img/web_gui_network_interface_dropdown.png
  :align: center
  :alt: System Interface Dropdown

  System Interface Dropdown

By changing interface and jumping to the Network Interface some options are going to be available.

.. _`section`: ../../advanced_features/interfaces/index.html

Dashboard
---------

.. toctree::
    :maxdepth: 1

    dashboard/dashboard
    ../../flow_dump/clickhouse/reports

Monitoring
----------

.. toctree::
    :maxdepth: 2

    ../shared/monitoring/active_monitoring
    ../shared/monitoring/infrastructure_monitoring
    monitoring/network_discovery
    ../shared/snmp/index
    monitoring/vulnerability_scan

Alerts
------

.. toctree::
    :maxdepth: 2

    ../shared/alerts/alerts_explorer
    alerts/flow_alerts_analyser
    ../shared/alerts/available_endpoints


Flows
-----

.. toctree::
    :maxdepth: 2

    flows/flows
    ../../flow_dump/clickhouse/historical_flows
    flows/server_ports


Hosts
-----

.. toctree::
    :maxdepth: 2

    hosts/hosts


Maps
----

.. toctree::
    :maxdepth: 3
    
    maps/analysis_map
    maps/geo_map
    maps/host_map


Interface
---------

.. toctree::
    :maxdepth: 2

    interface/interfaces
    interface/networks
    interface/host_pools
    interface/autonomouse_systems
    interface/countries
    interface/http_servers_local


Policies
---------

.. toctree::
    :maxdepth: 2

    ../shared/policies/access_control_list
    ../shared/policies/allowed_applications
    ../shared/policies/device_mac_address_tracking
    ../shared/policies/network_configuration
    ../shared/policies/traffic_rules
    ../shared/alerts/others/available_alerts
    ../shared/alerts/others/behavioural_checks_exclusion
    ../shared/policies/traffic_profiles
    

Settings
--------

.. toctree::
  :maxdepth: 2

  ../shared/settings/users
  ../shared/settings/preferences
  ../shared/settings/blacklists
  ../shared/settings/configurations
  ../shared/settings/applications_and_categories


Developer
---------

.. toctree::
  :maxdepth: 2

  ../shared/developer/rest_api
  ../shared/developer/analyze_pcap_file
  ../shared/developer/manage_data
  ../shared/developer/behavioural_checks
  ../shared/developer/alert_flow_status_definitions
  ../shared/developer/directories


Help
----

.. toctree::
  :maxdepth: 2

  ../shared/help/about
  ../shared/help/ntop_blog
  ../shared/help/report_an_issue


