# Changelog

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
- Extended and improved supported OSes: EdgeOS, Centos 6 and 7, Ubuntu 12.04 and 14.04, Debian, Windows XP, Vista, 7, 8, 10.
- Extended and improved supported architectures: x86, x86-64, MIPS, ARM.
- Documentation and User Guide significanly improved
- Added a great deal of READMEs, including ElasticSearch, bridging, traffic shaping and policing, NetBeans development
- Improved stability both under normal and high network loads
- Fixed tens of minor bugs 
