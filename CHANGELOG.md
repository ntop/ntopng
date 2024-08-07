# Changelog

#### ntopng 6.2 (August 2024)

## Breakthroughs
 - Code optimizations, reduce locks, replace with atomic when possible
 - Huge memory usage reduction (by more than half)
 - Huge improvements to SNMP polling
 - Add the possibility to replay historical flows on a virtual interface
 - Add support for ClickHouse Cloud and for TLS towards ClickHouse/SQLite
 - Add Cisco QoS MIB poll
 - Add Korean, Spanish and French translations
 - Add support to influxdb v.2 with compatible v.1 buckets
 - Add CheckMK syslog format
 - Add WeChat Alert endpoint
 - Add filtering ability to report page
 - Add MITRE alerts classification and Security report
 - Various tables refactoring, moved to new internal table component

## Improvements
 - Add flow_risk and host_risk remediations.
 - Add VLAN rules
 - Add drops/flows and probes info to view interface
 - Add exporters limits to ntopng licenses
 - Add extensions for asset inventory
 - Add feature sorting flows by protocol 
 - Add flows and drops ts to netflow/sflow exporters
 - Add info to nprobes and exporters pages
 - Add interface to SNMP topology map
 - Add localhost to ipaddress expection lists 
 - Add mac address to the hosts page
 - Add missing DHCP mappings 
 - Add mitre_info to alerts in ClickHouse
 - Add NAT info to ClickHouse and ECS
 - Add SIP status call
 - Add the ability to set custom alert score
 - Add uuid_num and unique_source_id to exporters and probes
 - Add various filters to Historical/Alerts pages
 - Add L2TP decapsulation
 - Add sankey to probes/exporters page
 - Add support for flow source
 - Add --disable-purge for debug purposes Added average flow throughtput in flows
 - Add support for Ethernet-over-IP tunnel support
 - Add SNMP interface and device usage page and timeseries 
 - Add detection of interfaces going down/up when open in pcap mode
 - Add host name discovered with DHCP 
 - Add blacklist charts
 - Add SNMP Trap support
 - Add QoS page to snmp
 - Add sankey to probes/exporters page
 - Add support for MAC addresses in traffic profiles
 - Add smcroute integration.
 - Add traffic profiles rules.
 - Add TCP flow connection state  
 - Add SNMP interface speed configuration 
 - Add report editor
 - Add support for ModBUS Scattered Holding Register Read
 - Add filtering ability to report page 
 - Add JE malloc support
 - Improve cloud support
 - Implement NetFlow polling device using coroutines
 - Implement flow traffic account in pcap interfaces when reading traffic from a pcap interface.
 - Implement mitre_table_info inside database 
 - Implement TLS swap heuristic similar to SSH
 - Improve host pool reload latency
 - Improve performance in SNMP device listing
 - Improve SNMP various performances and reworked interfaces page
 - Modify Lua allocator to avoid allocating small blocks and using ^2 blocks size to reduce heap fragmentation
 - Reduced memory and trhead usage Added missing HTTP server thread naming Added --limit-resources to tell ntopng to reduce memory usage (useful for systems with limited resources)
 - Rework periodic discovery code
 - Rework flow exporters lua stats
 - Rework interface polling with snmpbulk
 - Rework flow exporters host rules
 - Rework timeseries backend and added support to bar charts
 - Rework throughput calculation for flow-based interfaces: it is no longer calculated periodically but only when a new flow update is received
 - Update the dashboard with the editing component feature. 
 - Add support for interfaces of different datalink with pcap (e.g. -i ethX,tunY...)
 
## Changes 
 - Add ntopng to group systemd-journal
 - Add download of journalctl logs for the last day
 - Add hostnames to custom queries 
 - Add mapping between db fields and netflow
 - Add usage of proto.ndpi_confidence in flow_details.
 - Add SNMP import functionality for CSV files 
 - Add limit on DB interface flows accoring to the flow cache 
 - Add Major and Minor connection states
 - Add percentage and * as exporter device option in Flow Exporter rules + minor fixes.
 - Add option to backup redis (ntopng-utils-manage-config -a backup -r)
 - Add percentage and * as exporter device option in Flow Exporter rules + minor fixes.
 - Add check for avoiding crash with hosts with no MAC
 - Add trigger period action on shell script
 - Add exporters limits to ntopng licenses
 - Add memory boundaries checks
 - Add switch between normal and per minute traffic ts
 - Add icon in flows that indicate when the flow has swapped directions
 - Add flow exporter top chart
 - Add autosearch when opening edit application page
 - Add topk chart to conversations
 - Add support for ModBUS Scattered Holding Register Read
 - Add host location to flow page 
 - Add limitations for max number of polled SNMP devices
 - Add check for preventing false positive for long lived connections on top of protocols that can take a while
 - Add SNMP usage page
 - Add thpt charts to historical flows 
 - Add garbage collector calls
 - Add startup flush for ntopng.trace_error.alert_queue
 - Add Bootstrap 5 tooltip support
 - Add check to avoid memory issues (heap overflow) during DHCP packet dissection
 - Add check for avoid setting the interface in non-blocking mode when used with pcap files
 - Change the severity of the old blacklisted flow to critical
 - Change the labels from 'Downlink Usage' and 'Uplink Usage' to 'In Usage' and 'Out Usage'
 - Changed score level for various Alerts. 
 - Cleaned up flow throughout calculation
 - Disabled flow swap for UDP flows that might lead to false positives
 - Disable download image button on Safari.
 - Enable the editing of blacklist URL.
 - Enable interface name search. 
 - Enable search in the SNMP interfaces page. 
 - Make sort/delete persistent. Compute component_id on server side.
 - nmap command path is now computed at runtime
 - Packet padding is no longer accounted in flow traffic
 - Prevents non-admin users to pause interfaces
 - Report templates can now be defined in multiple paths
 - Reduced table retention
 - Remove additional http header
 - Remove sflowdev timeseries and unified to flowdev
 - Remove outdated unahandled flows that was casing fiscrepancies in flow accounting
 - Remove useless work when shutting down 
 - Run nmap setcap only when we're outside a container
 - Update doc with all the latest features.

## nEdge
 - Add option to enable external captive portal auth
 - Add Keep Src Address flag.
 - Add MAC and IP Address to radius interim-update
 - Add new fields to radius accounting
 - Add code to delete expired flows in ntopng still present in conntrack
 - Add check for offloaded flows with uncompleted protocol detection that have observed too many packets (updated via conntrack)
 - Implement remote radius authentication for local users (toggle)
 - Handle broadcast forwarding
 - Optimized std::map to reduce memory usage
 - Remove keep_src_address
 - Remove the hardcoded testing value for traffic_quota_ratio.
 - Remove alerts no longer necessary as they have been replaced by local traffic rules
 - Fix broadcast forwarding
 - Fix `Daily Traffic Quota` and `Daily Time Quota` column style.
 - Fix incorrect delta calculation
 - Fix repeater config modal reset
 - Fix the apply button in repeaters modal.
 - Fix progress bar.
 - Fix editing on repeater-config modal by removing unnecessary variable.
 - Fix the enable_nat and enable_iface toggles
 - Fix the alignment of column_key icons on the host_details/flows page.
 - Fix `Daily Traffic Quota` and `Daily Time Quota` column style.
 - Fix the alignment of column_info icons.

## Fixes
 - Fix top visited websites leak (growing undefinitely) and cpu load (sorting on every decoded site)
 - Fix aggregated live flows exporter filter.
 - Fix L7 Protocol usage & empty table statement using the view interface in Server Ports Analysis page 
 - Fix pcap extraction for unprivileged users
 - Fix chown group
 - Fix TCP Flow Reset check. 
 - Fix TCPFlowReset check. 
 - Fix free on uninitialized pointers
 - Fix the creation of the all_alerts_view in the ClickHouse cluster SQL script.
 - Fix the partition parameter in the ClickHouse cluster SQL database schema.
 - Fix a bug related to removing CVEs when a scan is in progress and make minor optimizations.
 - Fix the formatting of 0 percentage. 
 - Fix access to released memory in UT hash iteration
 - Fix navigation from server ports analysis chart view to table view.
 - Fix where on aggregated queries (interface id was ignored)
 - Fix invalid packet count with fragemented traffic
 - Fix info field cut after 256 characters
 - Fix crash and memory leak introduced
 - Fix missing fields in TLS alerts
 - Fix invalid application protocol accounting in network interfaces due to partial nDPi detection
 - Fix pcap download
 - Fix bug in UDP scan
 - Fix counter polling
 - Fix SSH flow swap heuristic
 - Fix segmentation fault on Stratosphere lab blacklist loading
 - Fix pcap polling on macOS and FreeBSD Fixes handling of interface pause (idle) on pcap interfaces
 - Fix SQL injection description
 - Fix copy not working on alert description (#8316)
 - Fix string info cut due to buffer size
 - Fix invalid host rename when using HTTP proxies
 - Fix reset counters does not reset sent/rcvd bytes/packets 
 - Fix attempt to index nil value
 - Fix some performance issues in the new flow page
 - Fix timeseries queries not working with serialize by mac
 - Fix incorrect check on TOS
 - Fix thpt historical flow chart
 - Fix historical flow charts
 - Fix duplicated entries in radius
 - Fix service map learning not reset at startup
 - Fix circular dependencies
 - Fix tooltip not working
 - Fix active monitoring alert discarded with no pool selected 
 - Fix incorrect hosts number
 - Fix issue with host pools assignment
 - Fix remote access alert not triggered 
 - Fix SNMP topology map and added to all snmp devices
 - Fix SNMP v3 import not working
 - Fix topology map not correctly working
 - Fix various translation to It, JP an other languages.
 - Fix various issue with application reloading
 - Fix various issues in SNMP Chart
 - Fix bytes per minute SNMP Serie not added
 - Fix shell script execution on alerts engaged 
 - Fix crash when sorting hosts in low memory conditions
 - Fix domain name extraction from the info column. 
 - Fix colors in dygraph plotters
 - Fix throughput values in local traffic rules. 
 - Fix wrong source type in exporters report
 - Fix emergency recipient toast not configured
 - Fix location not correctly set in case of aggregation
 - Fix unknown filter applied even when not filtered 
 - Fix schema id switch in influx
 - Fix Heap-buffer-overflow in IEC104
 - Fix influxdb top stats
 - Fix timeseries charts timezone and removed no more used files
 - Fix FreeBSD packaging issues with VulScan
 - Fix incorrect total calculation
 - Fix various issues on the exporter pages
 - Fix historical aggregated flow issue with timestamp lower than the last day
 - Fix various lua memory issues
 - CentOS 7 fixes
 - Workaround for a memory leak on windows for a bug on the pthread library
 - Various OT fixes

#### ntopng 6.0 (October 2023)

## Breakthroughs
 * New configurable Dashboard with new built-in templates
 * New configurable Traffic Report
 * New Vulnerability Scans & CVEs support
 * Add support to Periodic Reports notified via Recipients (e.g. email)
 * Add Inactive Hosts
 * Add PagerDuty integration
 * Add TheHive integration
 * Add support to Modbus and Modbus alerts
 * Add Server Ports Analysis page
 * Enable multithreading in active measurements (more accurate)
 * Migrate frontend chart timeseries library to Dygraph
 * Add support for MAC Address based RADIUS accounting
 * Improve OT, ICS, Scada support
 * Trigger External Host alerts directly from Lua (also for inactive hosts)
 * Add multicast forwarders
 * Implement host blackhole
 * Add support for LLDP id to MIB-II InterfaceId mapping
 * Add support for bidirectional rules
 * Add support for Enterprise XL bundle

## Improvements
 * Implement asynchronous VS scanning
 * Implement Ms Teams call detection
 * Optimize blacklist handling
 * Improve Network Map charts physics
 * Extend support to deliver notification to specific recipients
 * Improve traffic recording settings
 * Add support for Host Pools and Networks in Local Traffic Rules
 * Add search map
 * Add custom queries for Top Local/Remote hosts
 * Add Top receiver/sender networks custom queries
 * Add openvas support
 * Add new Vulners vulnerability scanner
 * Add ability to set probes aliases
 * Add MDNS, NETBios, HTTP historical filters
 * Improve FreeBSD clickhouse installation
 * Implement `-L <path>` for logging HTTP requests
 * Add -z for enabling timestamp reforge when reading pcap files
 * Improve dark mode css
 * Optimize ElasticSearch export (removed locks, increase export queue to 64K to handle spikes)
 * Add Radius chap validation
 * Add Radius auth protocol preference
 * Automated commit of clang-format CI changes
 * Add tool for creating nProbe topics in a kafka broker
 * Implement host score in Host scripts
 * Improvements for No-RX traffic analysis
 * Improve nProbe time drift check
 * Implement clickhouse retention
 * Add new page with snmp device rules
 * Add limit to discard clickhouse dump files
 * Improve IP/MAC association in SNMP

## Changes
 * Support multilple -m options
 * Rework nDPI stats
 * Add support for multiple email recipients
 * Add logic to enable generic checks if without a configuration
 * Add malware host contacted check
 * Use REST API to enable/disable checks
 * Disabled the reset of the email notification modal upon failed edit submission
 * Whitelisted locale page
 * Add ability to reset blacklist stats
 * Implement blacklist stats
 * Add mining currency in flow info
 * Add flag to use proxy in email settings
 * Reduced in simulate vlans option, the number of vlans
 * Restricted top flow chart for community version
 * Add input with suggestions component
 * Set capture direction for n2disk in zmq interfaces
 * Add explicit flag to enable flow export when recording on zmq interfaces
 * Add support for %NPROBE_INSTANCE_NAME
 * Add Ellio blocklist configuration (disabled by default)
 * Update to the latest nDPI risks
 * Email endpoint improvements
 * Improve notification message
 * Add download/upload buttons
 * Add possibility to send notification to recipients
 * Add multicast broadcast filter
 * Updated checks lists per license
 * Add feedback of correctly host inserted or already present
 * Take the score into account when computing the top alerted hosts
 * Add backend autorefresh support
 * Add flow exporter mapping to timeseries
 * Update default aggregation criteria in Aggregated live flows.
 * Add missing protocol mapping
 * Exported IP country information when using -F syslog
 * Change js formatting function for 'number' type, using thousands separator
 * Disabled LDAP support for FreeBSD
 * Add VLAN bidirectional traffic alert 
 * Handle JSON format for NXLOG in Kerberos plugin

## nEdge
 * Add dashboard templates for nedge pro and enterprise
 * Enable CH support on nEdge Enterprise
 * Enable throughput charts on nedge
 * Make Multicast repeater configurable
 * Add MDNS and multicast repeater
 * Major cleanup of (deprecated) nedge host pools code
 * Add support for custom informative captive portal
 * Set multiple LAN addresses in case of multiple LAN interfaces
 * Add inter-LANs policies
 * Always redirect somewhere on captive success, instead of displaying an empty page
 * nf_config API improvements

## Fixes
 * Fix edit rest in multicast forwarding
 * Fix missing validation functions
 * Fix traffic timeseries labels
 * Fix RedHat OS-name detection
 * Fix prototype pollution vulnerability
 * Fix thread pool spawning on freebsd
 * Fix Zoom handling
 * Fix behavior alert not triggered
 * Fix naming with timeseries
 * Fix nDPI protocol id issues
 * Fix RRD computation of sampled series with MAX as consolidated function
 * Fix flow alert where clause in write mode
 * Fix alert silencing not working
 * Fix application protocol ID using minor and major protocol
 * Fix UI spinner on loading
 * Fix recursive problem in active monitoring
 * Fix ts with vlans
 * Fix shutting down doesn't insert alerts in CH
 * Fix checks configuration initialization (default values) for new risks
 * Fix traffic behavior total not working in charts
 * Fix timeseries chart date format
 * Fix SSH flow swap heuristic
 * Fix avg empty value and added extra check for nan values in js
 * Fix pcap dynamically loaded not triggering alert
 * Fix ZMQ linking on Win
 * Fix date format
 * Fix blacklist counter stats
 * Fix flow alert queries on SQLite
 * Fix interface and local networks alerts not released
 * Fix flow devices not working with view interface
 * Fix flow exporters not seen with aggregated interfaces
 * Fix js regexes
 * Fix for validating correctly host and VLAN
 * Fix segv with custom protocols
 * Fix l7 metadata ingestion (e.g. dns query) when collecting from ZMQ
 * Fix hostname resolving
 * Fix ApexCharts formatter
 * Fix heap-buffer-overflow in MDNS packet dissection
 * Fix exclusion bitmap not correctly set
 * Fix some errors and leaks found while fuzzing locally
 * Fix Heap buffer overflow in IEC104Stats
 * Fix for memory management in packet-mode

#### ntopng 5.6 (February 2023)

## Breakthroughs
 * Add XL license
 * Add support Rocky9
 * Add support to Kafka
 * Increased max num of exporters
 * Introduce nTap support
 * Introduce support to ClickHouse Cluster
 * Rework Historical Chart Page
 * Rework pages using VueJS and moving towards responsive client

## Improvements
 * Handle allowed networks for unprivileged users
 * Improve multitenancy support
 * Improve thread names
 * Improve mac formatting
 * Improve top host sites adding reset method
 * Improve pcap upload
 * Improve ports formatting
 * Improve handling for Cisco NBAR collection
 * Improve source style
 * Improve Linux OS detection
 * Improve Engaged Time Report in Chart
 * Improve passive DNS hosty resolution
 * Improve alerts reports
 * Improve OPNsense installation instruction
 * Improve host report
 * Improve support to NDPI_TCP_ISSUES flow risk
 * Improve layout
 * Improve ICMP flow handling
 * Lowered memory consumption due to alert score
 * Rework pro code directories
 * Rework lua code
 * Rework flow aggregation
 * Rework capabilities support
 * Socket code cleanup
 * Use API to build interface report
 * Update rrd calculations
 * Update JP localization (courtesy of Yoshihiro Ishikawa)
 
## Changes
 * Add logo to package
 * Add missing deps
 * Add link to host
 * Add options to send report by email
 * Add Report class and example
 * Add internal server error on health/interfaces doc api
 * Add support for external (REST) host alerts
 * Add various help and parameters
 * Add script to create a pdf report from historical API data
 * Add NXLOG/Active Directory documentation
 * Add reload button in various pages
 * Add third party resources
 * Add flow exporter ips to observation points
 * Add support for the python API documentation
 * Add forced offline variable to mantain the --offline option
 * Add support for Lua host engaged alerts using timeout
 * Add observation points ts
 * Add HTTP server in flow details
 * Add token-based authentication https://www.ntop.org/guides/ntopng/advanced_features/authentication.html?highlight=token#token-based-authentication
 * Add Flow Risk (Bitmap) Filter in alerts
 * Add make targets for pip package Updated package classes
 * Add L7 information in flow object adding
 * Add CodeQL workflow for GitHub code scanning
 * Add modal-download-file component and add export timeseries png picture button
 * Add critical and emergency status to alerts
 * Add oneway TCP flows counters
 * Add support for nDPI network handling in flows
 * Add -n 4 for name resolution
 * Add IMAP/POP stats
 * Add Stratosphere Labs Blacklist support
 * Add support d3v7
 * Add Requires for RH9 (redhat-lsb-core is deprecated)
 * Add interfaces stats api and refactor the others health api
 * Add support to application protocol and master protocol
 * Add CIDR support in Historical Flows
 * Add new Aggregated Flows page
 * Add new Alerts Analysis page
 * Add support for estimating the number of TCP contacted servers with no reply
 * Add new Ports Analysis page
 * Add detection of periodic flows and exported it as flow risk in both flows and alerts
 * Add REST API to get DB columns and info
 * Add ability to query alerts from Python
 * Add Zoom streams handling
 * Add various checks
 * Add IP-in-IP decapsulation
 * Add Host Rules page (possiblity to trigger alerts based on timeseries)
 * Add the ability to analyze a pcap without creating a new interface
 * Add Windows timezone handling
 * Change table definition
 * Cleanup file names
 * Disabled host serialization
 * Enlarged the number of local networks to 1024
 * Increased upload size to 25 MB
 * Implement custom script check
 * Implement support of host filtering with TX traffic sent
 * Implement unresponsive peers host report
 * Implement count of incoming tx peers with TCP flows unanswered
 * Move ts business logic in ts_rest_utils.lua
 * Patch for handling nicely clock drift at startup
 * Remove obsolete autogen commands On Linux stay with g++ unless asnitizer is used
 * Remove REST API v0 (discontinued since ntopng 4.2)
 * Remove no more used severity
 * Refactor range-picker query_presets
 * Rework host packets page and removed dscp page
 * Rework host ports implementation
 * Rework Historical class
 * Rework OPNsense plugin package build
 * Self test fixes and improvements
 * Update documentation
 * Update REST API
 * Update bootstrap table css
 * Update various pages to vuejs
 * Update counter scaling (no gauge)
 * Update response in service disabled case

## nEdge
 * Add support to multi LAN and fixes DHCP service error
 * Add VLAN and multi WAN support to nedge
 * Add routing_policy to nedge configuration callback
 * Fix netplan configuration error
 * Update vlan trunk doc

## Fixes
 * Df columns error management, table export formatted with % and column reordering now working
 * Fix missing openssl dependency from MacOS
 * Fix clang
 * Fix host sankey minor issues
 * Fix hyperlinks to historical charts not working
 * Fix hyperlinks not working correctly
 * Fix Regex escape
 * Fix application name resolution on aggregated views
 * Fix RRD driver for step calaculation
 * Fix visual bugs with master and app proto
 * Fix various interface page minor bugs
 * Fix shortened labels
 * Fix default sort not working
 * Fix influxdb retention not updated
 * Fix name and size of charts
 * Fix vlan label not mapped
 * Fix for FreeBSD configure
 * Fix ip resolution not updating the name
 * Fix discrepancy in Traffic Calculation (Interface Chart)
 * Fix measurement units not uniform
 * Fix crash swap
 * Fix bug that reported wrong DNS information
 * Fix build process with opnsense/plugins
 * Fix validators regexps
 * Fix ICMP emtropy report Improved HTTP flows report
 * Fix Telegram Reported alerts contain HTML
 * Fix multi-series Charts are Unreadable in Dark Mode
 * Fix invalid reverse host resolution that caused hosts to be labelled with wrong symbolic name
 * Fix delete obsoleted code from page-stats
 * Fix for circular dependency js
 * Fix overlay not working
 * Fix due to changes to nDPI ALPN handling
 * Fix CSS Inconsistency Across Browsers
 * Fix Deep copy also for array of objects
 * Fix missing modules
 * Fix NAT handling with nprobe
 * Fix initialization crash
 * Removed multiple load from tables
 * ZMQ encryption key is now reported in hex to avoid escape problems
 
#### ntopng 5.4 (July 2022)

## Breakthroughs
* New search bar, with more results, information, links
* New listening ports page when collecting process information from nProbe (agent mode)
* New support for ELK version 8 and standardized ELK export format
* New packages for Ubuntu 22.04
* New Centrality Map in service map
* New Similarity Map
* Major performance improvements for periodic scripts
* New alert exclusion management (for checks and nDPI flow risks)
* Introduce Vue.js in the frontend
* Expose Chart Vue components for external websites

## Improvements
* Add new alerts (DHCP Storm, DNS Fragmented, Scan Detection, ...)
* Add Top Dropdown menu (Top Clients, Top Servers, ...) to the alert explorer
* Add ability to set historical flow permission to users
* Rework and Improve Maps (Service/Periodicity/Host)
* Improve buttons look and feel using latest Bootstrap version
* Improve Historical Flow and Alerts information (add many new fields for better analysis) 
* Improve IEC support (e.g. iec_invalid_transition)
* Add various mapping (DNS answers, DNS query types, ICMP answers, ...)
* Improve documentation, added all the available checks description
* Improve Exporter IP Flow Layout
* Improve ClickHouse queries performance with a better use of indexes
* Improve ZMQ flow idle timeout handling
* Updated ECS to 8.1 version
* Add various SNMP checks
* Add npm and Webpack support
* Add new alert exclusions fields (Domain and IssuerDN)
* Add DGA domain handling received via ZMQ
* Add Network matrix for view interfaces
* Add VLAN field support to alert exclusions
* Add Top Sites for flows collected from nProbe
* Add ELK dump frequency to Settings
* Implement Network/FQDN exclusion for alerts
* Add 'dpi' and 'guessed' badge to flow list and details
* Add support for L7 confidence
* Add ClickHouse search in JSON fields
* Add filters to Service/Periodicity maps
* Add --offline option to force offline mode in case of limited connectivity
* Add support for Active Monitoring selection in recipients
* Add copy button for all external link
* Allow download of PCAP in Historical Flows Explorer
* Add Flow Exporter to view interfaces
* Add ECS support to ELK flow dump
* Add MAC Address to View Interfaces
* Add Similarity check

## Changes
* Remove Telemetry
* Move UDP unidirection to nDPI alerts
* Disable flow dump to syslog on MacOS due to broken openlog API on Sierra and later
* Rework MAC/IP Reassociation alert used to detect spoofind and MITM (Man In The Middle) Attacks
* Separate data retention into Flow/Alerts data retention and Timeseries/Top data retention
* Reduce number of (unnecessary) threads 

## nEdge
* Add alert when a Gateway is unreachable
* Improve the Captive Portal

## Fixes
* Fix cookie attributes to the user and password cookies on the 302 redirect response
* Fix various GUI incorrect/undefined names
* Fix datatables incorrect data visualization
* Fix RRD timeseries implementation
* Fix log spam in case of endpoint not working
* Fix modals not hiding
* Fix alert/historical page filters not working correctly
* Fix bugs with flows informations while using View Interface
* Fix time format, shown as local instead of server time in some pages
* Fix format validations not correctly working
* Fix nProbe template flow mapping
* Fix access to uninitialized obj leading to segfault
* Fix idle time too low
* Fix invalid risk set from nDPI to ntopng's Flow class
* Fix dns large packets alert incorrectly triggered
* Fix network discovery
* Fix CSV download
* Fix bug that prevented flows to be dumped on ClickHouse
* Fix external URLs not correctly working
* Fix database initialization
* Fix IEC continuous dissection
* Fix NetBIOS name should not be used for hostnames
* Fix various CSS bugs
* Fix filter operators
* Fix name lookup
* Fix for detecting ZMQ drops
* Fix Historical Filters lost when switching windows
* Fix traffic directions with mirrored traffic
* Fix various API not correctly working
* Fix range picker not correctly working
* Fix crash when using interfaces with no database
* Fix various nil description
* Fix SIGABRT on shutdown with Views
* Fix for SNMP bridge alerting
* Fix external links not working
* Fix flow drilldown not correctly working

#### ntopng 5.2 (February 2022)

## Breakthroughs
* New ClickHouse support for storing historical data, replacing nIndex support (data migration available)
* Advanced Historical Flow Explorer, with the ability to define custom queries using JSON-based configurations
* New Historical Data Analysis page (including Score, Applications, Alerts, AS analysis), with the ability to define custom reports with charts
* Enhanced drill down from charts and historical flow data and alerts to PCAP data
* nEdge support for Ubuntu 20
* Enhanced support for Observation Points

## Improvements
* Improve CPU utilization and memory footprint
* Improve historical data retention management for flows and timeseries
* Improve periodic activities handling, with support for strict and relaxed (delayed) tasks
* Improve filtering and analysis of the historical flows
* Improve alert explorer and filtering
* Improve Enterprise dashboard look and feel
* Improve the speedtest support and servers selection
* Improve support for ping and continuous ping (ICMP) for active monitoring
* Improve flow-direction handling
* Improve localization (including DE and IT translations)
* Improve IPS policies management
  * Add IPS activities logging (e.g. block, unblock)
* Improve SNMP support
  * Optimize polling of SNMP devices
  * Improve SNMP v3 support
  * Add more information including version
  * Stateful SNMP alert to detect too many MACs on non-trunk
  * Perform fat MIBs poll on average every 15 minutes
  * Add preference to disable polling of SNMP fat MIBs
* Add more information to the historical flow data, including Latency, AS, Observation Points, SNMP interface, Host Pools
* Add detailed view of historical flows and alerts
* Add support for nProbe field L7_INFO
* Add ICMP flood alert
* Add Checks exclusion settings for subnets and for hosts and domains globally
* Add CDP support
* Add more regression tests
* Add support for obsolete client SSH version
* Add support for ERSPAN version 2 (type III)
* Add support for all the new nDPI Flow Risks added in nDPI 4.2
* Add extra info to service and periodicity map hosts
* Add Top Sites check
* REST API
  * Getter for the bridge MIB
  * Getter for LLDP adjacencies
  * Check for BPF filters
  * Score charts timeseries and analysis

## Changes
* Encapsulated traffic is accounted for the lenght of the encapsulated packet and not of the original packet
* Remove nIndex support, including the flow explorer
* Remove MySQL historical flow explorer (export only)
* Hide LDAP password from logs

## Fixes
* Fix a few memory leaks, double free, buffer overflow and invalid memory access
* Fix SQLite initialization
* Fix support for fragmented packets
* Fix IP validation in modals
* Fix netplan configuration manager
* Fix blog notifications
* Fix time range picker to support all browsers
* Fix binary application transfer name in alerts
* Fix glitches in chart drag operations
* Fix pools edit/remove
* Fix InfluxDB timeseries export
* Fix ELK memory leak
* Fix TLS version for obsolete TLS alerts when collecting flows
* Fix fields conversion in timeseries charts filters
* Fix some invalid nProbe field mapping
* Fix hosts Geomap
* Fix slow shutdown termination
* Fix wrong Call-ID 0 with RTP streams with no SIP stream associated
* Fix ping support for FreeBSD
* Fix active monitoring interface list
* Fix host names not always shown
* Fix host pools stats
* Fix UTF8 encoding issues in localization tools
* Fix time/timezone in forwarded syslog messages
* Fix unknown process alert
* Fix nil DOM javascript error
* Fix country not always shown in flow alerts
* Fix non-initialized traffic profiles
* Fix traffic profiles not working over ZMQ
* Fix syslog collection
* Fix async SNMP calls blocking the execution
* Fix CPU stats timeseries
* Fix InfluxDB attempts to alwa re-create retention policies
* Fix REST API ts.lua returning 24h data
* Fix processing of DNS packets under certain conditions
* Fix invalid space in SNMP Hostnames
* Fix REST API incompat. (/get/alert/severity/counters.lua, /get/alert/type/counters.lua)
* Fix map layout not saved correctly
* Fix LLDP topology for Juniper routers
* Fix not authorized error when editing SNMP devices
* Fix double 95perc, splitted avg and 95perc in sent/rcvd in charts
* Fix inconsistent local/remote timeseries
* Fix Risks generation in IPS policy configuration
* Fix deletion of sub-interface
* Fix deadline not honored when monitoring SNMP devices
* Fix traffic profiles on L7 protocols
* Fix TCP connection refused check
* Fix failures when the DB is not reacheable
* Fix segfault with View interfaces
* Fix hosts wrongly detected as Local
* Fix missing throughputs in countries

## Misc
* Enforces proxy exclusions with env var `no_proxy`
* Move Lua engine to 5.4
* Major code review and cleanup

## nEdge
* Add support for  Ubuntu 20
* Add ability to logout when using the Captive Portal
* Add per egress interface stats and timeseries
* Add active DHCP leases in UI and REST API
* Add daily/weekly/monthly quotas
* Add service and periodicity maps and alerts
* Fix Captive Portal not working due to invalid allowed interface
* Fix addition of static DHCP leases
* Fix factory reset
* Fix reboot button

#### ntopng 5.0 (August 2021)

## Breakthroughs

* Advanced alerts engine with security features, including the detection of [attackers and victims](https://www.ntop.org/ntopng/how-attackers-and-victims-detection-works-in-ntopng/)
  * Integration of 30+ [nDPI security risks](https://www.ntop.org/ndpi/how-to-spot-unsafe-communications-using-ndpi-flow-risk-score/) 
  * Generation of the `score` [indicator of compromise](https://www.ntop.org/ntopng/what-is-score-and-how-it-can-drive-you-towards-network-issues/) for hosts, interfaces and other network elements
* Ability to collect flows from hundredths of routers by means of [observation points](https://www.ntop.org/nprobe/collecting-flows-from-hundred-of-routers-using-observation-points/)
* Anomaly detection based on Double Exponential Smoothing (DES) to uncover possibly suspicious behaviors in the traffic and in the score
* Encrypted Traffic Analysis (ETA) with special emphasis on the TLS to uncover self-signed, expired, invalid certificates and other issues

## New features

* Ability to configure alert exclusions for individual hosts to mitigate false positives
* FreeBSD / OPNsense / pfSense [packages](https://packages.ntop.org/)
* Ability to see the TX/RX traffic breakdown both for physical interfaces and when receiving traffic from nProbe
* Add support for ECS when exporting to Syslog
* Improve TCP analysis, including analysis of TCP flows with zero window and low goodput
* Ability to send alerts to Slack
* Implementation of a token-based REST API access

## Improvements

* Rework the execution of hosts and flows checks (formerly user scripts), yielding a reduced CPU load of about 50%
* Improve 100Kfps+ [NetFlow/sFlow collection performance](https://www.ntop.org/nprobe/netflow-collection-performance-using-ntopng-and-nprobe/)
* Drilldown of [nIndex](https://www.ntop.org/guides/ntopng/advanced_features/flows_dump.html#nindex) historical flows much more flexible
* Migration to Bootstrap 5
* Check malicious JA3 signatures against all TLS-based protocols
* Rework Doh/DoT handling

## Fixes

* Fix SSRF and stored-XSS injected with malicious SSDP responses
* Fix several leaks in NetworkInterface

## Notes

* To ensure optimal performance and scalability and to prevent uneven resource utilization, the maximum number of interfaces handled by a single ntopng instance has been reduced to 
  * 16 (Enterprise M)
  * 32 (Enterprise L) 
  * 8  (all other versions)
* REST API v1/ is deprecated and will be dropped in the next stable release in favor of REST API v2/
* The old alerts dashboard has been removed and replaced by an advanced alerts drilldown page with integrated charts

----------------------------------------------------------------

#### ntopng 4.2 (October 2020)

## Breakthroughs

* [Flexible Alert Handling](https://www.ntop.org/ntopng/using-ntopng-recipients-and-endpoints-for-flexible-alert-handling/)
* Add recipients and endpoints to send alerts to different recipients on different channels, including email, Discord, Slack and [Elasticsearch](https://www.ntop.org/ntop/using-elasticsearch-to-store-and-correlate-ntopng-alarms/)
* Initial SCADA protocol support
* Many internal components of ntopng have been rewritten in order to improve the overall ntopng performance, reduce system load, and capable of processing more data while reducing memory usage with respect to 4.0.
* Cybersecurity extensions have been greatly enhanced by leveraging on the latest nDPI enhancements that enabled the creation of several user scripts able to supervise many security aspects of modern systems.
* Behavioral traffic analysis and lateral traffic movement detection for finding cybersecurity threats in traffic noise.
* Initial Scada support with native IEC 60870-5-104 support. We acknowledge switch.ch for having supported this development.
* Consolidation of Suricata and external alerts integration to further open ntopng to the integration of commercial security devices.
* SNMP support has been enhanced in terms of speed, SNMPv3 protocol support, and variety of supported devices.
* New REST API that enabled the integration of ntopng with third party applications such as CheckMK.

## New features

* Traffic Behavioral Analysis
  * [Periodic Traffic](https://www.ntop.org/ntopng/mice-and-elephants-howto-detect-and-monitor-periodic-traffic/)
  * Lateral Movements
  * TLS with self-signed certificates, issuerDN, subjectDN
* Support for [Industrial IOT and Scada](https://www.ntop.org/ndpi/monitoring-industrial-iot-scada-traffic-with-ndpi-and-ntopng/) with  modbus, DNP3 and IEC60870
* Support for [attack mitigation via SNMP](https://www.ntop.org/ntop/how-attack-mitigation-works-via-snmp/)
* Active monitoring
  * Support for ICMP v4/v6, HTTP, HTTPS and Speedtest
  * Ability to generate alerts upon unreachable or slow hosts or services
* Detection of unexpected servers
  * DHCP, NTP, SMTP, DNS
* Services map
* nIndex direct to maximixe flows dump performance
* [MacOS package](https://www.ntop.org/announce/introducing-ntopng-for-macos-finally/)

## Improvements

* Implements per-category indicator of compromise `score`
* Flexible configuration import/export/reset
  * Ability to import/export/reset all the ntopng configurations or parts of it
* Increased nIndex dump throughput by a factor 10
* Increased user scripts execution throughput
* Massive cleanup/simplifications of plugins to ease [community contributions](https://www.ntop.org/ntopng/a-step-by-step-guide-on-how-to-write-a-ntopng-plugin-from-scratch/)
* Improve cardinality estimation (e.g., number of contacted hosts, number of contacted ports) using [Hyper-Log-Log](https://en.wikipedia.org/wiki/HyperLogLog)
* Add DSCP information
* Rework handling of dissected virtual hosts to improve speed and reduce memory

## nEdge

* Support for hardware bypass

## Fixes

* Fix race conditions in view interfaces
* Fix crash when restoring serialized hosts in memory
* Fix conditions causing high CPU load
* Fix CSRF vulnerabilities when POSTing JSON
* Fix heap-use-after-free on HTTP dissected last_url

----------------------------------------------------------------

#### ntopng 4.0 (March 2020)

## Breakthroughs

* Plugins engine to tap into flows, hosts and other network elements
* Migration to Bootstrap 4 and Font Awesome 5 for a renewed ntopng look-and-feel with light and dark themes
* Processes and containers monitoring thanks to the eBPF integration via libebpfflow https://github.com/ntop/libebpfflow
* Active monitoring of hosts ICMP/ICMPv6/HTTP/HTTPS Round Trip Times (RTT)

## New features

* X.509 client certificate authentication
* ERSPAN transparent ethernet bridging
* Webhook export module for exporting alarms
* Identifications of the hosts in broadcast domain
* Category Lists editor to manage ip/domain lists
* Handling of PEN fields from nProbe
* Add anomalous flows to the looking glass
* Visibility of ICMP port-unreachable flows IPv4
* TCP states filtering (est., connecting, closed and rst)
* Ability to serialize local hosts in the broadcast domain via MAC address
* Japanese, portugese/brazilian localization
* Add process memory, cpu load, InfluxDB, Redis status pages and charts
* Implement ntopng Plugins, self contained modules to extend the ntopng functionalities
* Implement ZMQ/Suricata companion interface
* SSL traffic analysis and alerts via JA3 fingerprint, unsafe ciphers detection
* SSH traffic analysis and alerts via HASSH fingerprint
* Host traffic profile generation via the (MUD) Manufacturer Usage Descriptor
* Experimental Prometheus timeseries export
* Introduce the System interface to manage system wide settings and status
* Read events from Suricata and generate alerts
* SNMP network topology visualization
* Automatic ntopng update check and upgrade
* Calculate host anomaly score and trigger alerts when it exceeds a threshold
* Add ability to extract timeseries data with a click
* Initial Marketplace droplet using Fabric
* Alerts on duplex status change on SNMP interface

## Improvements

* View interfaces are now optimized for big networks and use less memory
* Systemd macros are now used to start/restart the ntopng services
* Handles n2disk traffic extractions from recording processes non managed by ntopng
* Interface in/out now available also for non PF_RING interfaces (read from /proc)
* Automatic InfluxDB rollup support
* MDNS discovery improvements
* Rework of the alerts engine and api for efficient engaged alerts triggering
* Faster ZMQ communication to nProbe thanks to the implementation of a binary TLV format
* Stats update for ZMQ interfaces is now based on the idle/active flows timeout
* Timeseries export improvements via queues, detect if InfluxDB is down and stop the export
* Implemented reusable Lua engine to reduce the overhead of periodic scripts
* Improve Lua error handling
* Exclude certain categories from Elephant/Long lived flows alerts

## nEdge

* Ability to set up port forwarding
* Support for Ubuntu 18.04
* Fix users and other prefs deleted during nEdge data reset
* Japanese localization
* Block unsupported L3 protocols (currently only ARP and IPv4 are supported)
* DNS mapping port to avoid conflicts with system programs

## Fixes

* Fix export to mysql on shutdown in case of Pcap file in community mode
* Fix failing SYN-scan detection
* Fix ZMQ decompression errors with large templates
* Fix possible XSS in login.lua referer param and `runtime.lua`
* Update geolocation due to changes in the library usage policy
* Fix to support browsers dark mode
* Option `--zmq-encryption-key <pub key>` can be used with `-I <endpoint>` to encrypt data hi hierarchical mode
* Fix nIndex missing data while performing some queries and throughput calculation

----------------------------------------------------------------

#### ntopng 3.8 (December 2018)

## New features

* Remote assistance to temporarily grant encrypted ntopng access to remote
parties
  * Works with a transparent overlay-network spawned on-demand just
  for the time necessary for the assistance
  * Passes through firewalls and NATs
  * https://www.ntop.org/ntopng/use-remote-assistance-to-connect-to-ntopng-instances/
* Custom URLs and IP addresses mappings to traffic categories
  * Ability to associate websites (HTTP and HTTPS) to certain traffic
  categories using their names
  * Ability to use IP addresses (IPv4 and IPv6) to associate hosts to
  traffic categories
  * https://www.ntop.org/guides/ntopng/web_gui/categories.html?highlight=categories#custom-category-hosts
* Continuous traffic recording
  * Interfaces with n2disk for the recording and extraction of traffic
  * https://www.ntop.org/guides/ntopng/traffic_recording.html
* Download live pcap captures of monitored hosts and interfaces
  * Delivers packets in pcap format over the web
  * Works with single hosts, interfaces
  * Allows BPF filters
  * https://www.ntop.org/guides/ntopng/advanced_features/live_pcap_download.html?highlight=pcap#live-pcap-download
* User activities logging
  * Records an alerts ntopng web users activities, including changes
  in the configurations, deletion/addition of new users, login
  attempts, and password changes.
  * http://www.ntop.org/guides/ntopng/basic_concepts/alerts.html
* Extended chart metrics
  * Relative-Strength Index (RSI)
  * Moving and Exponentially-Moving Averages
  * https://www.ntop.org/guides/ntopng/web_gui/historical.html

## Improvements

* Alerts
  * Scan-detection for remote hosts
  * Configurable alerts for long-lived and elephant flows
  * InfluxDB export failed alerts
  * Remote-to-remote host alerts
  * Optional JSON alerts export to Syslog
* Improve InfluxDB support
  * Handles slow and aborted queries
  * Uses authentication
* Adds RADIUS and HTTP authenticators
 * Options to allow users login via RADIUS and HTTP
 * https://www.ntop.org/ntopng/remote-ntopng-authentication-with-radius-and-ldap/
* Lua 5.3 support
 * Improve performance
 * Better memory management
 * Native support for 64-bit integers
 * Native support for bitwise operations
* Adds the new libmaxminddb geolocation library
* Storage utilization indicators
  * Global storage indicator to show the disk used by each interface
  * Per-interface storage indicator to show the disk used to store timeseries and flows 
* Support for Sonicwall PEN field names
* Option to disable LDAP referrals
* Requests and configures Keepalive support for ZMQ sockets
* Three-way-handshake detection
* Adds SNMP mac addresses to the search function

## nEdge

* Implement nEdge policies test page
* Implement device presets
* DNS
  * Add more DNS servers
  * Remove deprecated DNS


## Fixes

* Fix missing flows dump on shutdown
* HTTP dissection fixes
* SNMP
  * Fix SNMP step when high resolution timeseries are enabled
  * Fix SNMP devices permissions to prevent non-admins to delete or add devices
* Properly handles endianness over ZMQ
  * Fix early expiration of some TCP flows
  * Fix non-deterministic expiration of flows

----------------------------------------------------------------

#### ntopng 3.6 (August 2018)

## New features

* New pro charts
  * Ability to compare data with the past (time shift)
  * Trend lines based on ASAP
  * Average and percentile lines overlayed on the graph and animated
  * New color scheme that uses pastel colors for better visualization
  * https://www.ntop.org/ntopng/ntopng-and-time-series-from-rrd-to-influxdb-new-charts-with-time-shift/
* New timeseries API with support for RRD and InfluxDB
  * Abstracts and handles multiple sources transparently
  * https://www.ntop.org/guides/ntopng/api/lua/timeseries/index.html
* Streaming pcap captures with BPF support
  * Download live packet captures right from the browser
* New SNMP devices caching
  * Periodically cache information of all the SNMP device configured
  * Calculate and visualize interfaces throughput


## Improvements

* Security
  * Access to the web user interface is controlled with ACLs
  * Secure ntopng cookies with SameSite and HttpOnly
  * HTTP cookie authentication
  * Improve random session id generation
* Various SNMP improvemenets
  * Caching
  * Interfaces status change alerts
  * Device interfaces page
  * Devices and interfaces added to flows
  * Fix several library memory leaks
  * Improve device and interface charts
  * Interfaces throughput calculation and visualization
  * Ability to delete all SNMP devices at once
* Improve active devices discovery
  * OS detection via HTTP User-Agent
* Alerts
  * Crypto miners alerts toggle
  * Detection and alerting of anomalous terminations
  * Module for sending telegram.org alerts
  * Slack
    * Configurable Slack channel names
    * Add Slack test button
* Charts
  * Active flows vs local hosts chart
  * Active flows vs interface traffic chart
* Ubuntu 18.04 support
* Support for ElasticSearch 6 export
* Add support for custom categories lists
* Add ability to use the non-JIT Lua interpreter
* Improve ntopng startup and shutdown time
* Support for capturing from interface pairs with PF_RING ZC
* Support for variable PPP header lenght
* Migrated geolocation to GeoLite2 and libmaxminddb
* Configuration backup and restore
* Improve IE browser support
* Using client SSL certificate for protocol detection
* Optimized host/flows purging


## nEdge

* Netfilter queue fill level monitoring
* Bridging support with VLANs
* Add user members management page
* Add systemd service alias to ntopng
* Captive portal fixes
* Informative captive portal (no login)
* Improve captive portal support with WISPr XML
* Disabled global DNS forging by default
* Add netfilter stats RRDs
* Fix bad MAC traffic increment
* Fix slow shutdown/reboot
* Fix invalid banned site redirection
* Fix bad gateway status
* Fix gateway network unreacheable when gateway is down
* Fix SSL traffic not blocked when captive portal is active
* Fix invalid read during local DNS lookup
* Workaround for dhclient bug stuck while a lease already exists


## Fixes

* SNMP
  * Fix SNMP devices deletion
  * Fix format for odd SNMP interfaces speed
  * Fix SNMP community selection
* Fix MDNS decoding
* Fix login redirection
* Fix MAC manufacturers escaping
* Fix host validation errors
* Fix traffic throughput burst when loading a serialized host
* Allowing multiple consecutive dots in password fields
* Rework shutdown to allow graceful periodic activities termimation
* Fix validation error in profiles with spaces in names
* Fix old top talkers stats deletion
* Fix 32-bit integers pushed to Lua
* Fix service dependency from pfring
* Fix for enabling broken SSL certificate mismatch alerts
* Fix allowed interfaces users access
* Fix for crashes on Windows
* Fix lua platform dependent execution
* Fix subnet search in hist data explorer
* Fix flow devices and sflow mappings with SNMP
* Fix invalid login page encoding
* LDAP fixes (overflow, invalid LDAP fields length)
* Fix encoding for local/LDAP UTF-8 passwords
* Add POST timeout to prevent housekeeping from blocking indefinitely
* Windows resize fixes
* Fix invalid uPnP URL
* Fix wrong hosts retrv by pool id, OS, network, and country
* Fix JS errors with IE browser
* Fix custom categories matching

----------------------------------------------------------------

#### ntopng 3.4 (April 2018)


## New features

* Improve alerts generation
  * Send alerts via email
  * SNMP alerts on port status change
  * Alerts at ntopng startup/shutdown
  * ARP/IP re-assignments alerts
  * Beta support for InfluxDB and Prometheus
* Multi-language support
  * English
  * Italian
  * German
* "hide-from-top" to selectively hide hosts from top stats


## Improvements

* Discovery with SSH scan and MDNS dissection
* HTML documentation with ReadTheDocs
* ERSPAN Type 2 detunneling
* per-AS network latency stats
* TCP KeepAlive stats
* Redis connection via Unix domain socket


## Security Fixes

* Disables CGI support in mongoose
* Hardened options parsing


## Fixes

* Fix memory leaks with SNMP
* Fix possible out-of-bounds reads with SSDP dissection

----------------------------------------------------------------

#### ntopng 3.2 (December 2017)


## New features

* Support for the official ntopng Grafana datasource plugin
  * Plugin available at: https://grafana.com/plugins/ntop-ntopng-datasource
* Newtork devices discovery
  * Discovery of smartphones, laptops, IoT devices, routers, smart TVs, etc
  * Device type and operating system detection
  * ARP scan, SSDP dissection, Multicast DNS (MDNS) resolution
  * DHCP fingerprinting
* Adds an active flows page to the AS details
* Bridge mode
  * Enforcement of global per-pool time and byte quotas
  * Support of per-host traffic shapers
  * Add support for banned sites detection with informative splash screen
  * Implement per-host/mac/pool flow drop count
* nDPI traffic categories and RRDs
* Implements MySQL database interoperability between ntopng and nProbe


## Improvements

* Flows sent by nProbe over ZMQ:
  * Batched, compressed ZMQ flow format to optimize data exchange
  * Use of post-nat src/dst addresses and ports
  * Handles multiple balanced ZMQ endpoints
* Periodic tasks performed by a thread-pool to optimize cores utilization
* Hosts and devices are walked in batches to greatly reduce Lua VM memory
* Full systemd support for Debian, Ubuntu, Centos, and Raspbian
* Extended sFlow support to include sample packet drops and counter stats in interface views
* Stacked applications and categories charts for ASes, Networks, etc

## Security Fixes

* More restrictive permissions for created files and directories
* Fix of a possible dissectHTTP reads beyond end of payload

----------------------------------------------------------------

#### ntopng 3.0 (May 2017)

## New features (Community)

* Layer-2 Devices
  * MAC devices page
  * Implement MAC last seen tracking in redis
  * Manufacturer filter and sort
* Host pools (logical groups of hosts)
* Logstash flow export extension
* Implemented data anonymization: hosts and top sites
* Implements CPU load average and memory usage
* Virtual Interfaces
  * ZMQ: disaggregate based on probeIP or ingress interfaceId
  * Packet: disaggregate on VLANId
* ElasticSearch and MySQL flow export statistics
* Tiny Flows
* Alerts
  * Implements alerts on a per-interface per-vlan basis
  * Global alert thresolds for all local hosts/interfaces/local networks
  * LUA alerts generation
  * Adds hosts stateful syn attacks alerts
  * Visualization/Retrieval of Host Alerts
  * Add the ability to generate alert when ntopng detects traffic produced by malware hosts
  * Slack integration: send alerts to slack
  * Alerts for anomalous flows
  * Host blacklisted alerts
  * Alerts delete by type, older than, by host
  * SSL certificates mismatch alerts generation
* Implement SSL/TLS handshake detection
* Integrated MSDN support
* Implemented DHCP dissection for name resolution

## New features

* Traffic bridging
  * Per host pool, per host pool member policies
  * Per L7 protocol category policies
  * Flashstart categories to block
  * Time and Traffic quotas
  * Support to google Safe Search DNS
  * Ability to set custom DNS
* Captive portal
  * Limited lifetime users
  * Support for pc, kindle, android, ipad devices
* SNMP
  * Periodic SNMP device monitoring and polling
  * Historical SNMP timeseries
  * Host-to-SNMP devices mapping
* Daily/Weekly/Monthly Traffic Report: per host, interface, network
* Add ability to define host blacklists
* DNS flow characterization with FlashStart (www.flashstart.it)
* Flow LUA scripts: on flow creation, protocol detected, expire
* Periodic MySQL flows aggregation
* Batched MySQL flows insertions
* sFlow device/interface counters
* Implementation of flow devices stats

## Improvements

* Allows web server binding to system ports for non-privileged users
* Improve VLAN support
* Improve IPv6 support
* Implements a script to add users from the command line
* View interfaces rework
* Reported number of Layer-2 devices in ntopng footer
* Preferences re-organization and search
* Adds RIPE integration for Autonomous Systems
* Search host by custom name
* Move to the UTF-8 encoding
* Make real-time statics refresh time configurable (footer, dashboard)
* Adds support for localization (i18n)
* Traffic bridging: improved stability
* Traffic profiles: improved stability and data persistence
* Charts
  * Improve historical graphs
  * Traffic report rework and optimizations
  * Improves the responsiveness and interactivity of historical exploration (ajax)
  * Stacked top hosts
  * Add ZMQ flows/sec graph
  * Profiles graphs
  * Implement ICMP detailed stats for local hosts
  * ASN graphs: traffic and protocols history
  * ARP requests VS replies sent and received by hosts
  * Implement host TCP flags distribution
  * DNS packets ratio
  * FlashStart category graphs
  * Add ARP protocol in interface statistics
  * SNMP port graphs

## Voip (nProbe required)

* Changes and rework for SIP and RTP protocol
* Adds VoIP SIP to RTP flow search
* Improves VoIP visualization (RTP)

## Security Fixes

* Disable TLS 1.0 (vulnerable) in mongoose
* Disabled insecure cyphers in SSL (when using ntopng over SSL)
* Hardens the code to prevent SQL injections
* Enforce POST form CSRF to prevent programmer mistakes
* Strict GET and POST parameters validation to prevent XSS
* Prevent HTTP splitting attacks
* Force default admin password change

----------------------------------------------------------------

#### ntopng 2.4.0

- Fundamental memory-management, stability and speed improvements
- Security fixes to prevent privileges escalation and XSS
- Improve alerts with support for
	- Re-arming
	- Nagios
	- Network-based triggers
	- Suspicious probing attempts
- Netfilter support with optional packet dropping features
- Routing visibility through RIPE
- Hosts/flows listing and grouping facilities implemented directly into the C core rather than in Lua
- Fine-grained historical data drill-down features in the Professional/Small Business version. Features include top talkers, top applications, and interactions between hosts.
- Integrations with other tools:
	- LDAP authentication support
	- alerts forwarding/withdrawal to Nagios
	- nBox integration to request pcaps of monitored flows
	- Apache Kafka flows export
- Extended and improved traffic *monitoring*:
	- TCP sessions throughput estimations and state breakdown (e.g., established, reset, etc.)
	- Goodput monitoring
	- Trends detection
	- Highlight of low-goodput flows and hosts
	- Add hosts top-visited sites
- Built-in support for:
	- GRE detunnelling
	- per-VLAN historical statistics
	- ICMP and ICMPv6 dissection
- Extended and improved supported OSes: Ubuntu 16, Debian 7, EdgeOS
- Optional support for hosts categorization via service `flashstart.it`
- New options:
	- `--capture-direction` that allows the user to chose which direction to monitor (tx only, rx only, or both)
	- `--zmq-collector-mode` to assure proper nProbe flow collection  behind firewalls
	- `--online-license-check` for to check licenses online
	- `--print-ndpi-protocols` to print nDPI Layer-7 application protocols supported

#### ntopng 2.2.0

- Implementation of **traffic profiles**, logical flow-based aggregations -- e.g., Facebook traffic originating at host X. Real-time statistics as well as historical data are collected for each traffic profile
- Add a **fine-grained network traffic breakdown** that captures and stores ingress, egress, and inner traffic for each local network
- Ex-novo redesign of historical interfaces. Historical interface data have been seamlessly integrated with real-time data
- Historical flow dump and runtime drill-down of historical data with support for MySQL and ElasticSearch
- Built-in support for protocols:
  - CAPWAP (Control And Provisioning of Wireless Access Points, <https://tools.ietf.org/html/rfc5415>)
  - BATMAN (<http://www.open-mesh.org/projects/open-mesh/wiki/BATMANConcept>)
  - TZSP (TaZmen Sniffer Protocol)
- Add SIP and RTP protocols information in flow details
- Additional MAC-based host classification
- Add support for Linux TUN/TAP devices in TUN mode
- Extended and improved supported OSes: EdgeOS, Centos 6/7, Ubuntu 12.04/14.04, Debian, Windows x64, Raspbian (Raspberry)
- Extended and improved supported architectures: x86, x86-64, MIPS, ARM.
- Documentation and User Guide significantly improved
- Add a great deal of READMEs, including ElasticSearch, bridging, traffic shaping and policing, NetBeans development
- Improve stability both under normal and high network loads
- Fix tens of minor bugs
