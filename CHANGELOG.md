# Changelog

#### ntopng 4.2 (October 2020)

## Breakthroughs

* [Flexible Alert Handling](https://www.ntop.org/ntopng/using-ntopng-recipients-and-endpoints-for-flexible-alert-handling/)
  * Added recipients and endpoints to send alerts to different recipients on different channels, including email, Discord, Slack and [Elasticsearch](https://www.ntop.org/ntop/using-elasticsearch-to-store-and-correlate-ntopng-alarms/)
* Scalable SNMP v2c/v3 support

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
* Improved cardinality estimation (e.g., number of contacted hosts, number of contacted ports) using [Hyper-Log-Log](https://en.wikipedia.org/wiki/HyperLogLog)
* Added DSCP information
* Reworked handling of dissected virtual hosts to improve speed and reduce memory

## nEdge

* Support for hardware bypass

## Fixes

* Fixed race conditions in view interfaces
* Fixed crash when restoring serialized hosts in memory
* Fixed conditions causing high CPU load
* Fixes CSRF vulnerabilities when POSTing JSON
* Fixes heap-use-after-free on HTTP dissected last_url


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
* Added anomalous flows to the looking glass
* Visibility of ICMP port-unreachable flows IPv4
* TCP states filtering (est., connecting, closed and rst)
* Ability to serialize local hosts in the broadcast domain via MAC address
* Japanese, portugese/brazilian localization
* Added process memory, cpu load, InfluxDB, Redis status pages and charts
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

* Fixed export to mysql on shutdown in case of Pcap file in community mode
* Fixed failing SYN-scan detection
* Fixed ZMQ decompression errors with large templates
* Fixed possible XSS in login.lua referer param and `runtime.lua`
* Update geolocation due to changes in the library usage policy
* Fixes to support browsers dark mode
* Option `--zmq-encryption-key <pub key>` can be used with `-I <endpoint>` to encrypt data hi hierarchical mode
* Fixed nIndex missing data while performing some queries and throughput calculation

----------------------------------------------------------------

## New features

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
* Improved InfluxDB support
  * Handles slow and aborted queries
  * Uses authentication
* Adds RADIUS and HTTP authenticators
 * Options to allow users login via RADIUS and HTTP
 * https://www.ntop.org/ntopng/remote-ntopng-authentication-with-radius-and-ldap/
* Lua 5.3 support
 * Improved performance
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

* Fixes missing flows dump on shutdown
* HTTP dissection fixes
* SNMP
  * Fix SNMP step when high resolution timeseries are enabled
  * Fixes SNMP devices permissions to prevent non-admins to delete or add devices
* Properly handles endianness over ZMQ
  * Fixes early expiration of some TCP flows
  * Fixes non-deterministic expiration of flows

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
  * Improved random session id generation
* Various SNMP improvemenets
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
