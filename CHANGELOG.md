# Changelog

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
- Additional MAC-based host calassification
- Added support for Linux TUN/TAP devices in TUN mode
- Extended and improved supported OSes: EdgeOS, Centos 6/7, Ubuntu 12.04/14.04, Debian, Windows x64, Raspbian (Raspberry)
- Extended and improved supported architectures: x86, x86-64, MIPS, ARM.
- Documentation and User Guide significantly improved
- Added a great deal of READMEs, including ElasticSearch, bridging, traffic shaping and policing, NetBeans development
- Improved stability both under normal and high network loads
- Fixed tens of minor bugs 
