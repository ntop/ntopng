.. _nAnalystToolsLicensing:

Tools and Licensing
====================

nAnalyst exposes network intelligence functions to the AI agent as discrete tools. Which tools are available depends on your ntopng license: higher tiers unlock progressively more tools, following the same license model used throughout ntopng (see :ref:`versions and licensing <AvailableVersions>`).

Tier model
----------

+-------------------------+-----------------------------------------------+
| Tier                    | What it unlocks                                |
+=========================+=================================================+
| Community               | Live host/flow/LAN visibility tools            |
+-------------------------+-----------------------------------------------+
| Pro                     | Live flow inspection, protocol lookup,         |
|                          | documentation search, timeseries, network      |
|                          | services config                                |
+-------------------------+-----------------------------------------------+
| Enterprise M            | ClickHouse SQL query, table listing, schema    |
|                          | introspection                                  |
+-------------------------+-----------------------------------------------+
| Enterprise L             | Charts, Sankey/chord diagrams, geomap,          |
|                          | historical flow data, VLAN traffic, ICS/SCADA   |
|                          | protocol stats, Wazuh alerts, ACL rules         |
+-------------------------+-----------------------------------------------+
| Enterprise XL            | SNMP device monitoring, alert exclusion        |
|                          | management, asset inventory, site/exporter     |
|                          | topology                                       |
+-------------------------+-----------------------------------------------+
| nAnalyst add-on         | AI security policy creation and management     |
+-------------------------+-----------------------------------------------+

Higher tiers always include everything unlocked by lower tiers. Gating is enforced per-tool in code (each tool file declares its own ``min_edition`` in ``opts``) — this table reflects the actual runtime check, not just documentation intent.

Available tools
----------------

**Community**

- ``add_active_monitoring_script`` — enable a new active monitoring script for a host
- ``discover_lan`` — list devices visible on the LAN
- ``get_country_stats`` — top countries by traffic
- ``get_host_info`` — live traffic statistics for a host
- ``get_interface_addresses`` — IP addresses on a monitored interface
- ``get_live_flows_for_host`` — active flows for a given IP
- ``get_live_flows_summary`` — aggregated summary of active flows
- ``get_mac_info`` — MAC address details and manufacturer
- ``list_available_active_monitoring_scripts`` — all available monitoring scripts
- ``list_enabled_active_monitoring_scripts`` — currently enabled monitoring scripts
- ``list_expected_servers`` — approved network servers
- ``list_networks`` — list configured local network CIDR subnets for an interface

**Pro**

- ``get_host_info`` — live host statistics, extended with QoE/DNS/TCP health data
- ``get_live_flow`` — current live flow data for a specific flow
- ``list_protos`` — nDPI protocols/applications by category
- ``resolve_proto`` — resolve protocol names or IDs
- ``search_docs`` — search ntopng/nProbe documentation and CLI reference
- ``get_asn_config`` — configured ASN policies (customer, sub-customer, remote ASNs)
- ``list_timeseries`` — discover available timeseries schemas, tags, and metrics for an entity
- ``get_timeseries`` — fetch timeseries data as a compact min/max/avg/last summary, optionally with a line-chart artifact
- ``get_network_services_config`` — configured DNS/NTP/DHCP/SMTP/gateway servers

**Enterprise M**

- ``query`` — execute a ClickHouse SQL query
- ``list_tables`` — list queryable ClickHouse tables
- ``describe_table`` — get the schema of a ClickHouse table

**Enterprise L**

- ``chart`` — render query results as a chart (pie, line, bar, bubble, heatmap)
- ``chord`` — render a chord relationship diagram
- ``geomap`` — render a geographic heatmap or live host map
- ``sankey`` — render a Sankey flow-path diagram
- ``get_historical_flow`` — fetch historical flow data from ClickHouse
- ``get_access_control_list`` — configured flow-level ACL rules (allow/deny by protocol/client/server/port)
- ``get_vlan_traffic`` — VLAN traffic broken down by port/protocol, live or historical, as a Sankey artifact
- ``get_modbus_stats`` — Modbus (ICS/SCADA) protocol statistics for a flow
- ``get_profinet_stats`` — PROFINET (ICS/SCADA) protocol statistics for a flow
- ``get_s7comm_stats`` — S7comm (Siemens ICS/SCADA) protocol statistics for a flow
- ``get_wazuh_alerts`` — security alerts ingested from Wazuh (external SIEM/HIDS integration)

**Enterprise XL**

- ``add_certificate_alert_exclusion`` — exclude a TLS certificate from alerts
- ``add_domain_alert_exclusion`` — exclude a domain from alerts
- ``add_host_alert_exclusion`` — exclude a host from alerts
- ``get_asset_info`` — persistent identity/inventory data for a network asset
- ``get_snmp_device_config`` — SNMP polling configuration for a device
- ``get_snmp_device_info`` — full SNMP device snapshot (system, interfaces, neighbors)
- ``get_snmp_interface_details`` — detailed stats for a single SNMP interface
- ``get_snmp_interface_roles`` — SNMP agent IPs with their interfaces and interface roles (transit, peering, access, etc)
- ``list_snmp_devices`` — all SNMP-monitored devices
- ``get_infrastructure_stats`` — aggregate infrastructure-wide stats across all interfaces
- ``list_sites`` — configured sites and their associated networks
- ``get_site_traffic`` — traffic exchanged between sites (site-to-site matrix)
- ``get_site_sankey`` — site-to-site traffic as a Sankey diagram artifact
- ``list_flow_exporters`` — NetFlow/sFlow/IPFIX exporters (probes) feeding ntopng
- ``get_top_exporter_interfaces`` — top flow-exporter interfaces by traffic volume
- ``get_exporter_sites_map`` — flow exporters grouped by site, as a graph or Sankey artifact
- ``get_observation_point_exporters`` — flow exporters reporting to a specific observation point
- ``get_network_policy`` — restricted host networks (local/corporate devices) and whitelisted networks/MACs

**nAnalyst add-on**

- ``create_ai_policy`` — create a new AI security policy from a description
- ``list_ai_policies`` — list all configured AI security policies

**nEdge only**

- ``get_nedge_firewall_policy`` — configured inter-LAN firewall rules and default policy (distinct from ``get_access_control_list``, which covers flow-level ACLs)

If the agent attempts to call a tool your license does not include, that tool is never registered for the session — it is invisible to the agent, not merely rejected at call time. The same tool set is used regardless of the client (chat interface or :ref:`MCP <nAnalystMCP>`).

Timeseries tools are deliberately summary-first: ``get_timeseries`` returns per-series min/max/avg/last/num_points instead of raw data points, to avoid flooding the agent's context window with large point arrays. Pass ``"chart":true`` when the user wants to see a trend visually — this additionally renders a line-chart artifact with the full series, without changing the compact text summary returned to the model.
