# Changelog

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
  * Improved random session id generation
* Various SNMP improvements
  * Caching
  * Interfaces status change alerts
  * Device interfaces page
  * Devices and interfaces added to flows
  * Fixed several library memory leaks
  * Improved device and interface charts
  * Interfaces throughput calculation and visualization
  * Ability to delete all SNMP devices at once
* Improved active devices discovery
  * OS detection via HTTP User-Agent
* Alerts
  * Crypto miners alerts toggle
  * Detection and alerting of anomalous terminations
  * Module for sending telegram.org alerts
  * Slack
    * Configurable Slack channel names
    * Added Slack test button
* Charts
  * Active flows vs local hosts chart
  * Active flows vs interface traffic chart
* Ubuntu 18.04 support
* Support for ElasticSearch 6 export
* Added support for custom categories lists
* Added ability to use the non-JIT Lua interpreter
* Improved ntopng startup and shutdown time
* Support for capturing from interface pairs with PF_RING ZC
* Support for variable PPP header lenght
* Migrated geolocation to GeoLite2 and libmaxminddb
* Configuration backup and restore
* Improved IE browser support
* Using client SSL certificate for protocol detection
* Optimized host/flows purging


## nEdge

* Netfilter queue fill level monitoring
* Bridging support with VLANs
* Added user members management page
* Added systemd service alias to ntopng
* Captive portal fixes
* Informative captive portal (no login)
* Improved captive portal support with WISPr XML
* Disabled global DNS forging by default
* Added netfilter stats RRDs
* Fixed bad MAC traffic increment
* Fixed slow shutdown/reboot
* Fixed invalid banned site redirection
* Fixed bad gateway status
* Fixed gateway network unreacheable when gateway is down
* Fixed SSL traffic not blocked when captive portal is active
* Fixed invalid read during local DNS lookup
* Workaround for dhclient bug stuck while a lease already exists


## Fixes

* SNMP
  * Fixed SNMP devices deletion
  * Fixed format for odd SNMP interfaces speed
  * Fixed SNMP community selection
* Fixed MDNS decoding
* Fixed login redirection
* Fixed MAC manufacturers escaping
* Fixed host validation errors
* Fixed traffic throughput burst when loading a serialized host
* Allowing multiple consecutive dots in password fields
* Reworked shutdown to allow graceful periodic activities termimation
* Fixed validation error in profiles with spaces in names
* Fixed old top talkers stats deletion
* Fixed 32-bit integers pushed to Lua
* Fixed service dependency from pfring
* Fixes for enabling broken SSL certificate mismatch alerts
* Fixed allowed interfaces users access
* Fixes for crashes on Windows
* Fixed lua platform dependent execution
* Fixed subnet search in hist data explorer
* Fixed flow devices and sflow mappings with SNMP
* Fixed invalid login page encoding
* LDAP fixes (overflow, invalid LDAP fields length)
* Fixed encoding for local/LDAP UTF-8 passwords
* Added POST timeout to prevent housekeeping from blocking indefinitely
* Windows resize fixes
* Fixed invalid uPnP URL
* Fixed wrong hosts retrv by pool id, OS, network, and country
* Fixed JS errors with IE browser
* Fixed custom categories matching

----------------------------------------------------------------

#### ntopng 3.4 (April 2018)


## New features

* Improved alerts generation
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

* Fixes memory leaks with SNMP
* Fixes possible out-of-bounds reads with SSDP dissection

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
  * Added support for banned sites detection with informative splash screen
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
  * Implemented MAC last seen tracking in redis
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
  * Added the ability to generate alert when ntopng detects traffic produced by malware hosts
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
* Added ability to define host blacklists
* DNS flow characterization with FlashStart (www.flashstart.it)
* Flow LUA scripts: on flow creation, protocol detected, expire
* Periodic MySQL flows aggregation
* Batched MySQL flows insertions
* sFlow device/interface counters
* Implementation of flow devices stats


## Improvements

* Allows web server binding to system ports for non-privileged users
* Improved VLAN support
* Improved IPv6 support
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
  * Improved historical graphs
  * Traffic report rework and optimizations
  * Improves the responsiveness and interactivity of historical exploration (ajax)
  * Stacked top hosts
  * Add ZMQ flows/sec graph
  * Profiles graphs
  * Implemented ICMP detailed stats for local hosts
  * ASN graphs: traffic and protocols history
  * ARP requests VS replies sent and received by hosts
  * Implement host TCP flags distribution
  * DNS packets ratio
  * FlashStart category graphs
  * Added ARP protocol in interface statistics
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
- Improved alerts with support for
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
	- Added hosts top-visited sites
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
- Added a **fine-grained network traffic breakdown** that captures and stores ingress, egress, and inner traffic for each local network
- Ex-novo redesign of historical interfaces. Historical interface data have been seamlessly integrated with real-time data
- Historical flow dump and runtime drill-down of historical data with support for MySQL and ElasticSearch
- Built-in support for protocols:
  - CAPWAP (Control And Provisioning of Wireless Access Points, <https://tools.ietf.org/html/rfc5415>)
  - BATMAN (<http://www.open-mesh.org/projects/open-mesh/wiki/BATMANConcept>)
  - TZSP (TaZmen Sniffer Protocol)
- Added SIP and RTP protocols information in flow details
- Additional MAC-based host classification
- Added support for Linux TUN/TAP devices in TUN mode
- Extended and improved supported OSes: EdgeOS, Centos 6/7, Ubuntu 12.04/14.04, Debian, Windows x64, Raspbian (Raspberry)
- Extended and improved supported architectures: x86, x86-64, MIPS, ARM.
- Documentation and User Guide significantly improved
- Added a great deal of READMEs, including ElasticSearch, bridging, traffic shaping and policing, NetBeans development
- Improved stability both under normal and high network loads
- Fixed tens of minor bugs
