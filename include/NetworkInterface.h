/*
 *
 * (C) 2013-21 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#ifndef _NETWORK_INTERFACE_H_
#define _NETWORK_INTERFACE_H_

#include "ntop_includes.h"

/** @defgroup NetworkInterface Network Interface
 * ............
 */

class Flow;
class FlowHash;
class Host;
class HostHash;
class Mac;
class MacHash;
class VLAN;
class VLANHash;
class AutonomousSystem;
class AutonomousSystemHash;
class OperatingSystem;
class OperatingSystemHash;
class Country;
class CountriesHash;
class DB;
class Paginator;
class NetworkInterfaceTsPoint;
class ViewInterface;
class FlowAlert;
class HostAlert;
class FlowChecksLoader;
class FlowChecksExecutor;
class HostCheck;
class HostChecksLoader;
class HostChecksExecutor;

#ifdef NTOPNG_PRO
class L7Policer;
class FlowInterfacesStats;
class TrafficShaper;
class NIndexFlowDB;
#endif

/** @class NetworkInterface
 *  @brief Main class of network interface of ntopng.
 *  @details .......
 *
 *  @ingroup NetworkInterface
 *
 */
class NetworkInterface : public NetworkInterfaceAlertableEntity {
 protected:
  char *ifname, *ifDescription;
  u_int8_t ifMac[6];
  bpf_u_int32 ipv4_network_mask, ipv4_network;
  const char *customIftype;
  u_int8_t purgeRuns;  
  u_int32_t bridge_lan_interface_id, bridge_wan_interface_id;
  u_int32_t num_alerts_engaged[ALERT_ENTITY_MAX_NUM_ENTITIES];
  /* Counters for active alerts. Changed by multiple concurrent threads */
  std::atomic<u_int64_t> num_active_alerted_flows_notice;  /* Counts all flow alerts with severity <= notice  */
  std::atomic<u_int64_t> num_active_alerted_flows_warning; /* Counts all flow alerts with severity == warning */
  std::atomic<u_int64_t> num_active_alerted_flows_error;   /* Counts all flow alerts with severity >= error   */
  u_int32_t num_host_dropped_alerts, num_flow_dropped_alerts, num_other_dropped_alerts;
  u_int64_t num_written_alerts, num_alerts_queries, score_as_cli, score_as_srv;
  u_int64_t num_new_flows;
  struct {
    u_int32_t local_hosts, remote_hosts;
  } tot_num_anomalies;
  AlertsQueue *alertsQueue;
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  PeriodicityMap *pMap;
  ServiceMap *sMap;
#endif

  /* The executor is per-interfaces, and uses the loader to configure itself and execute flow checks */
  FlowChecksExecutor *flow_checks_executor, *prev_flow_checks_executor;
  HostChecksExecutor *host_checks_executor, *prev_host_checks_executor;

#if defined(NTOPNG_PRO)
  /* Map containing various stats resetted every day */
  CheckTrafficMap *check_traffic_stats;
  time_t nextMinPeriodicUpdate;
  /* Behavioural analysis regarding the interface */
  AnalysisBehavior *score_behavior, *traffic_tx_behavior, *traffic_rx_behavior;
#endif
  
  /* Variables used by top sites periodic update */
  u_int8_t current_cycle = 0;
  FrequentStringItems *top_sites;
  char *old_sites;

  FrequentStringItems *top_os;
  char *old_os;

  /* Flows queues waiting to be dumped */
  SPSCQueue<Flow *> *idleFlowsToDump, *activeFlowsToDump;
  Condvar dump_condition; /* Condition variable used to wait when no flows have been enqueued for dump */
  

  /* Queues for the execution of flow user scripts.
     See scripts/plugins/examples/example/checks/flow/example.lua for the checks
   */
  SPSCQueue<FlowAlert *> *flowAlertsQueue;
  SPSCQueue<HostAlertReleasedPair> *hostAlertsQueue;

  /*
    Flag to indicate whether a flow JSON should be dumped along with the flow. Flow JSON contain
    additional fields not placed inside database columns.
  */
  bool flows_dump_json;
  /*
    Flag to indicate whether JSON labels should be used for flow fields inside the dumped flow
    JSON. If this flag is false, flow fields are keyed with nProbe integer flow keys.
   */
  bool flows_dump_json_use_labels;

  /* Queue containing the ip@vlan strings of the hosts to restore. */
  StringFifoQueue *hosts_to_restore;

  RwLock observationLock;
  std::map<u_int16_t /* observationPointId */, ObservationPointIdTrafficStats*> observationPoints;
  
  /* External alerts contain alertable entities other than host/interface/network
   * which are dynamically allocated when an alert for them occurs.
   * A lock is necessary to guard the insert/delete operations from lookup operations
   * requested from the GUI and to ensure that a delete operation does generate
   * a use-after-free. */
  std::map<std::pair<AlertEntity, std::string>, AlertableEntity*> external_alerts;
  Mutex external_alerts_lock;

  bool is_view;                  /* Whether this is a view interface */
  ViewInterface *viewed_by;      /* Whether this interface is 'viewed' by a ViewInterface */
  u_int8_t viewed_interface_id;  /* When this is a 'viewed' interface, this id represents a unique interface identifier inside the view */

  /* Disaggregations */
  u_int16_t numSubInterfaces;
  std::set<u_int32_t>  flowHashingIgnoredInterfaces;
  FlowHashingEnum flowHashingMode;
  std::map<u_int64_t, NetworkInterface*> flowHashing;

  /* Network Discovery */
  NetworkDiscovery *discovery;
  MDNS *mdns;

  /* Broadcast domain */
  BroadcastDomains *bcast_domains;
  bool reload_hosts_bcast_domain, lbd_serialize_by_mac;
  time_t hosts_bcast_domain_last_update;

  u_int16_t next_compq_insert_idx;
  u_int16_t next_compq_remove_idx;
  ParsedFlow **companionQueue;
  bool enable_ip_reassignment_alerts;
  
  /* Live Capture */
  Mutex active_captures_lock;
  u_int8_t num_live_captures;
  struct ntopngLuaContext *live_captures[MAX_NUM_PCAP_CAPTURES];
  static bool matchLiveCapture(struct ntopngLuaContext * const luactx,
			       const struct pcap_pkthdr * const h,
			       const u_char * const packet,
			       Flow * const f);
  void deliverLiveCapture(const struct pcap_pkthdr * const h, const u_char * const packet, Flow * const f);

  string ip_addresses;
  AddressTree interface_networks;
  int id;
  bool bridge_interface;

  bool is_dynamic_interface;             /* Whether this is a dynamic interface */
  bool show_dynamic_interface_traffic;   /* Show traffic of this dynamic interface */
  u_int64_t dynamic_interface_criteria;  /* Criteria identifying this dynamic interface */
  FlowHashingEnum dynamic_interface_mode; /* Mode (e.g., Probe IP, VLAN ID, etc */


  bool is_traffic_mirrored, is_loopback;
  bool discard_probing_traffic;
  bool flows_only_interface; /* Only allocates flows for the interface (e.g., no hosts, ases, etc) */
  ProtoStats discardedProbingStats;
#ifdef NTOPNG_PRO
  L7Policer *policer;
#ifndef HAVE_NEDGE
  FlowProfiles  *flow_profiles, *shadow_flow_profiles;
  SubInterfaces *sub_interfaces;
#endif
  CustomAppStats *custom_app_stats;
  FlowInterfacesStats *flow_interfaces_stats;
#endif
  EthStats ethStats;
  std::map<u_int32_t, u_int64_t> ip_mac; /* IP (network byte order) <-> MAC association [2 bytes are unused] */
  u_int32_t arp_requests, arp_replies;
  ICMPstats icmp_v4, icmp_v6;
  LocalTrafficStats localStats;
  int pcap_datalink_type; /**< Datalink type of pcap. */
  pthread_t pollLoop,
    flowDumpLoop /* Thread for the database dump of flows */,
    flowChecksLoop /* Thread for the execution of flow user script hooks */,
    hostChecksLoop /* Thread for the execution of host user script hooks */
    ;
  Condvar flow_checks_condvar, host_checks_condvar;
  bool pollLoopCreated, flowDumpLoopCreated, flowAlertsDequeueLoopCreated, hostAlertsDequeueLoopCreated;
  bool has_too_many_hosts, has_too_many_flows, mtuWarningShown;
  bool flow_dump_disabled;
  u_int32_t ifSpeed, numL2Devices, numHosts, numLocalHosts, scalingFactor;
  /* Those will hold counters at checkpoints */
  u_int64_t checkpointPktCount, checkpointBytesCount, checkpointPktDropCount, checkpointDroppedAlertsCount;
  u_int64_t checkpointDiscardedProbingPktCount, checkpointDiscardedProbingBytesCount;
  u_int16_t ifMTU;
  int cpu_affinity; /**< Index of physical core where the network interface works. */
  nDPIStats *ndpiStats;
  PacketStats pktStats;
  DSCPStats *dscpStats;
  L4Stats l4Stats;
  SyslogStats syslogStats;
  FlowHash *flows_hash; /**< Hash used to store flows information. */
  u_int32_t last_remote_pps, last_remote_bps;
  TimeseriesExporter *influxdb_ts_exporter, *rrd_ts_exporter;

  TcpFlowStats tcpFlowStats;
  TcpPacketStats tcpPacketStats;
  ThroughputStats bytes_thpt, pkts_thpt;
  struct timeval last_periodic_stats_update;

  MacHash *gw_macs; /**< Hash used to identify traffic direction based on gw MAC. */
  bool gw_macs_reload_requested;

  /* Mac */
  MacHash *macs_hash; /**< Hash used to store MAC information. */

  /* Autonomous Systems */
  AutonomousSystemHash *ases_hash; /**< Hash used to store Autonomous Systems information. */

  /* Operating Systems */
  OperatingSystemHash *oses_hash; /**< Hash used to store Operating Systems information. */

  /* Countries */
  CountriesHash *countries_hash;

  /* VLANs */
  VLANHash *vlans_hash; /**< Hash used to store VLAN information. */

  /* Hosts */
  HostHash *hosts_hash; /**< Hash used to store hosts information. */
  bool purge_idle_flows_hosts, inline_interface;
  DB *db;
  StatsManager  *statsManager;
  AlertStore *alertStore;
  HostPools *host_pools;
  VLANAddressTree *hide_from_top, *hide_from_top_shadow;
  bool has_vlan_packets, has_ebpf_events, has_mac_addresses, has_seen_dhcp_addresses;
  bool has_seen_pods, has_seen_containers, has_external_alerts;
  time_t last_pkt_rcvd, last_pkt_rcvd_remote, /* Meaningful only for ZMQ interfaces */
    next_idle_flow_purge, next_idle_host_purge, next_idle_other_purge;
  bool running, is_idle;
  NetworkStats **networkStats;
  InterfaceStatsHash *interfaceStats;
  dhcp_range* dhcp_ranges, *dhcp_ranges_shadow;

  PROFILING_DECLARE(32);

  void init();
  void deleteDataStructures();

  NetworkInterface* getDynInterface(u_int64_t criteria, bool parser_interface);
  Flow* getFlow(Mac *srcMac, Mac *dstMac, VLANid vlan_id,
		u_int16_t observation_domain_id,
		u_int32_t deviceIP, u_int32_t inIndex, u_int32_t outIndex,
		const ICMPinfo * const icmp_info,
		IpAddress *src_ip, IpAddress *dst_ip,
		u_int16_t src_port, u_int16_t dst_port,
		u_int8_t l4_proto,
		bool *src2dst_direction,
		time_t first_seen, time_t last_seen,
		u_int32_t len_on_wire,
		bool *new_flow, bool create_if_missing);
  int sortHosts(u_int32_t *begin_slot,
		bool walk_all,
		struct flowHostRetriever *retriever,
		u_int8_t bridge_iface_idx,
		AddressTree *allowed_hosts,
		bool host_details,
		LocationPolicy location,
		char *countryFilter, char *mac_filter,
		VLANid vlan_id, OSType osFilter,
		u_int32_t asnFilter, int16_t networkFilter,
		u_int16_t pool_filter, bool filtered_hosts,
		bool blacklisted_hosts, bool hide_top_hidden,
		bool anomalousOnly, bool dhcpOnly,
		const AddressTree * const cidr_filter,
		u_int8_t ipver_filter, int proto_filter,
		TrafficType traffic_type_filter,
		char *sortColumn);
  int sortASes(struct flowHostRetriever *retriever,
	       char *sortColumn);
  int sortOSes(struct flowHostRetriever *retriever,
         char *sortColumn);
  int sortCountries(struct flowHostRetriever *retriever,
	       char *sortColumn);
  int sortVLANs(struct flowHostRetriever *retriever,
		char *sortColumn);
  int sortMacs(u_int32_t *begin_slot,
	       bool walk_all,
	       struct flowHostRetriever *retriever,
	       u_int8_t bridge_iface_idx,
	       bool sourceMacsOnly,
	       const char *manufacturer,
	       char *sortColumn, u_int16_t pool_filter, u_int8_t devtype_filter,
	       u_int8_t location_filter, time_t min_first_seen);
  int sortFlows(u_int32_t *begin_slot,
		bool walk_all,
		struct flowHostRetriever *retriever,
		AddressTree *allowed_hosts,
		Host *host,
		Paginator *p,
		const char *sortColumn);

  /* Functions used to update top sites of the interface */
  void saveOldSitesAndOs(u_int8_t top);
  void getCurrentTime(struct tm *t_now);
  void deserializeTopOsAndSites(char* redis_key_current, bool do_top_sites);
  void serializeDeserialize(struct tm *t_now, bool do_serialize);
  void removeRedisSitesKey();
  void addRedisSitesKey();

  bool isNumber(const char *str);
  bool checkIdle();
  bool checkPeriodicStatsUpdateTime(const struct timeval *tv);
  void topItemsCommit(const struct timeval *when);
  void checkMacIPAssociation(bool triggerEvent, u_char *_mac, u_int32_t ipv4, Mac *host_mac);
  void checkDhcpIPRange(Mac *sender_mac, struct dhcp_packet *dhcp_reply, VLANid vlan_id);
  void pollQueuedeCompanionEvents();
  bool getInterfaceBooleanPref(const char *pref_key, bool default_pref_value) const;
  virtual void incEthStats(bool ingressPacket, u_int16_t proto, u_int32_t num_pkts,
			   u_int32_t num_bytes, u_int pkt_overhead) {
    ethStats.incStats(ingressPacket, num_pkts, num_bytes, pkt_overhead);
    ethStats.incProtoStats(proto, num_pkts, num_bytes);
  };

  /*
    Dequeues alerted flows up to `budget` and executes `flow_lua_check` on each of them.
    The number of flows dequeued is returned.
   */
  u_int64_t dequeueFlowAlerts(u_int budget);

  u_int64_t dequeueHostAlerts(u_int budget); /* Same as above but for hosts */
  u_int16_t guessEthType(const u_char *p, u_int len, u_int8_t *is_ethernet);
    
 public:
  /**
  * @brief A Constructor
  * @details Creating a new NetworkInterface with all instance variables set to NULL.
  *
  * @return A new instance of NetworkInterface.
  */
  NetworkInterface();
  NetworkInterface(const char *name, const char *custom_interface_type = NULL);
  virtual ~NetworkInterface();

  bool initFlowChecksLoop(); /* Initialize the loop to dequeue flows for the execution of user script hooks */
  bool initHostChecksLoop(); /* Same as above but for hosts */
  bool initFlowDump(u_int8_t num_dump_interfaces);
  u_int32_t getASesHashSize();
  u_int32_t getOSesHashSize();
  u_int32_t getCountriesHashSize();
  u_int32_t getVLANsHashSize();
  u_int32_t getMacsHashSize();
  u_int32_t getHostsHashSize();
  virtual u_int32_t getFlowsHashSize();

  void updateSitesStats();
  void updateBroadcastDomains(VLANid vlan_id,
			      const u_int8_t *src_mac, const u_int8_t *dst_mac,
			      u_int32_t src, u_int32_t dst);

  virtual bool walker(u_int32_t *begin_slot,
		      bool walk_all,
		      WalkerType wtype,
		      bool (*walker)(GenericHashEntry *h, void *user_data, bool *entryMatched),
		      void *user_data);

  void checkDisaggregationMode();
  void incrVisitedWebSite(char *hostname);
  void incrOS(char *hostname);
  inline void incScoreValue(u_int16_t score_incr, bool as_client)  { as_client ? score_as_cli += score_incr : score_as_srv += score_incr; };
  inline void decScoreValue(u_int16_t score_incr, bool as_client)  { as_client ? score_as_cli -= score_incr : score_as_srv -= score_incr; };
  inline void setCPUAffinity(int core_id)      { cpu_affinity = core_id; };
  inline void getIPv4Address(bpf_u_int32 *a, bpf_u_int32 *m) { *a = ipv4_network, *m = ipv4_network_mask; };
#if defined(NTOPNG_PRO)
  void luaTrafficMap(lua_State *vm);
  void enableTrafficMap(bool enable);
  inline bool isTrafficMapEnabled() { return(check_traffic_stats != NULL); };
  inline bool updateCheckTrafficMap(IpAddress *ip, Mac *mac, VLANid vlan_id, TrafficStatsMonitor updated_stats) { return(check_traffic_stats) ? check_traffic_stats->updateElement(ip, mac, vlan_id, updated_stats) : false; };
#endif
  inline bool are_ip_reassignment_alerts_enabled()       { return(enable_ip_reassignment_alerts); };
  inline AddressTree* getInterfaceNetworks()   { return(&interface_networks); };
  virtual void startPacketPolling();
  virtual void startFlowDumping();
  virtual void shutdown();
  virtual void cleanup();
  virtual char *getEndpoint(u_int8_t id)       { return NULL;   };
  virtual bool set_packet_filter(char *filter) { return(false); };
  virtual void incrDrops(u_int32_t num)        { ; }
  /* calling virtual in constructors/destructors should be avoided
     See C++ FAQ Lite covers this in section 23.7
  */
  virtual bool isPacketInterface() const {
    return(getIfType() != interface_type_FLOW && getIfType() != interface_type_ZMQ);
  }

  virtual bool isSyslogInterface() const {
    return(getIfType() == interface_type_SYSLOG);
  }
  void incSyslogStats(u_int32_t num_total_events, u_int32_t num_malformed,
                      u_int32_t num_dispatched, u_int32_t num_unhandled, u_int32_t num_alerts,
                      u_int32_t num_host_correlations, u_int32_t num_collected_flows) {
    syslogStats.incStats(num_total_events, num_malformed, num_dispatched, num_unhandled,
      num_alerts, num_host_correlations, num_collected_flows);
  };

#if defined(linux) && !defined(HAVE_LIBCAP) && !defined(HAVE_NEDGE)
  /* Note: if we miss the capabilities, we block the overriding of this method. */
  inline bool
#else
  virtual bool
#endif
		      isDiscoverableInterface(){ return(false);                              }
  inline virtual char* altDiscoverableName()   { return(NULL);                               }
  virtual const char* get_type()    const      { return(customIftype ? customIftype : CONST_INTERFACE_TYPE_UNKNOWN); }
  virtual InterfaceType getIfType() const      { return(interface_type_UNKNOWN); }
  inline FlowHash *get_flows_hash()            { return flows_hash;     }
  inline TcpFlowStats* getTcpFlowStats()       { return(&tcpFlowStats); }
  virtual bool is_ndpi_enabled() const         { return(true);          }
  inline u_int  getNumnDPIProtocols()          { return(ndpi_get_num_supported_protocols(get_ndpi_struct())); };
  inline time_t getTimeLastPktRcvdRemote()     { return(last_pkt_rcvd_remote); };
  inline time_t getTimeLastPktRcvd()           { return(last_pkt_rcvd ? last_pkt_rcvd : last_pkt_rcvd_remote); };
  inline void  setTimeLastPktRcvd(time_t t)    { if(t > last_pkt_rcvd) last_pkt_rcvd = t; };
  inline const char* get_ndpi_category_name(ndpi_protocol_category_t category) { return(ndpi_category_get_name(get_ndpi_struct(), category)); };
  inline char* get_ndpi_proto_name(u_int id)   { return(ndpi_get_proto_name(get_ndpi_struct(), id));   };
  inline int   get_ndpi_proto_id(char *proto)  { return(ndpi_get_protocol_id(get_ndpi_struct(), proto));   };
  inline int   get_ndpi_category_id(char *cat) { return(ndpi_get_category_id(get_ndpi_struct(), cat));     };
  inline char* get_ndpi_proto_breed_name(u_int id) { return(ndpi_get_proto_breed_name(get_ndpi_struct(), ndpi_get_proto_breed(get_ndpi_struct(), id))); };
  inline char* get_ndpi_full_proto_name(ndpi_protocol protocol, char *buf, u_int buf_len) const { return(ndpi_protocol2name(get_ndpi_struct(), protocol, buf, buf_len)); }
  inline u_int get_flow_size()                 { return(ndpi_detection_get_sizeof_ndpi_flow_struct()); };
  inline u_int get_size_id()                   { return(ndpi_detection_get_sizeof_ndpi_id_struct());   };
  inline char* get_name() const                { return(ifname);                                       };
  inline char* get_description() const         { return(ifDescription);                                };
  inline int  get_id() const                   { return(id);                                           };
  inline bool get_inline_interface()           { return inline_interface;  }
  virtual bool hasSeenVLANTaggedPackets() const{ return(has_vlan_packets); }
  inline void setSeenVLANTaggedPackets()       { has_vlan_packets = true;  }
  inline bool hasSeenEBPFEvents() const        { return(has_ebpf_events);  }
  inline void setSeenEBPFEvents()              { has_ebpf_events = true;   }
  inline bool hasSeenMacAddresses() const      { return(has_mac_addresses); }
  inline void setSeenMacAddresses()            { has_mac_addresses = true;  }
  inline bool hasSeenDHCPAddresses() const     { return(has_seen_dhcp_addresses); }
  inline void setDHCPAddressesSeen()           { has_seen_dhcp_addresses = true;  }
  inline bool hasSeenPods() const              { return(has_seen_pods); }
  inline void setSeenPods()                    { has_seen_pods = true; }
  inline bool hasSeenContainers() const        { return(has_seen_containers); }
  inline void setSeenContainers()              { has_seen_containers = true; }
  inline bool hasSeenExternalAlerts() const    { return(has_external_alerts);  }
  inline void setSeenExternalAlerts()          { has_external_alerts = true;   }
  struct ndpi_detection_module_struct* get_ndpi_struct() const;
  inline bool is_purge_idle_interface()        { return(purge_idle_flows_hosts);               };
  int dumpFlow(time_t when, Flow *f);
  bool getHostMinInfo(lua_State* vm, AddressTree *allowed_hosts, char *host_ip, VLANid vlan_id, bool only_ndpi_stats);

  /* Enqueue alert to a queue for processing and later delivery to recipients */
  bool enqueueFlowAlert(FlowAlert *alert);
  bool enqueueHostAlert(HostAlert *alert);
  /*
    Enqueue flows to be processed by the view interfaces.
    Viewed interface enqueue flows using this method so that the view
    can periodicall dequeue them and update its statistics;
   */
  bool viewEnqueue(time_t t, Flow *f);
#ifdef NTOPNG_PRO
  void flushFlowDump();
#endif
  void checkPointHostTalker(lua_State* vm, char *host_ip, VLANid vlan_id);
  int dumpLocalHosts2redis(bool disable_purge);
  inline void incRetransmittedPkts(u_int32_t num)   { tcpPacketStats.incRetr(num);      };
  inline void incOOOPkts(u_int32_t num)             { tcpPacketStats.incOOO(num);       };
  inline void incLostPkts(u_int32_t num)            { tcpPacketStats.incLost(num);      };
  inline void incKeepAlivePkts(u_int32_t num)       { tcpPacketStats.incKeepAlive(num); };
  virtual void checkPointCounters(bool drops_only);
  bool registerSubInterface(NetworkInterface *sub_iface, u_int64_t criteria);

  /* Overridden in ViewInterface.cpp */
  virtual u_int64_t getCheckPointNumPackets();
  virtual u_int64_t getCheckPointDroppedAlerts();
  virtual u_int64_t getCheckPointNumBytes();
  virtual u_int32_t getCheckPointNumPacketDrops();
  virtual u_int64_t getCheckPointNumDiscardedProbingPackets() const;
  virtual u_int64_t getCheckPointNumDiscardedProbingBytes() const;
  inline void incFlagStats(u_int8_t flags, bool cumulative_flags) {
    pktStats.incFlagStats(flags, cumulative_flags);
  };

  inline void incStats(bool ingressPacket, time_t when,
			u_int16_t eth_proto,
			u_int16_t ndpi_proto, ndpi_protocol_category_t ndpi_category,
			u_int8_t l4proto,
			u_int32_t pkt_len, u_int32_t num_pkts) {
    /* NOTE: nEdge does the incs in NetfilterInterface::incStatsConntrack, keep it in sync! */
#ifndef HAVE_NEDGE
    incEthStats(ingressPacket, eth_proto, num_pkts, pkt_len, getPacketOverhead());
    ndpiStats->incStats(when, ndpi_proto, 0, 0, num_pkts, pkt_len);
    // Note: here we are not currently interested in packet direction, so we tell it is receive
    ndpiStats->incCategoryStats(when, ndpi_category, 0 /* see above comment */, pkt_len);
    pktStats.incStats(1, pkt_len);
    l4Stats.incStats(when, l4proto,
		     ingressPacket ? num_pkts : 0, ingressPacket ? pkt_len : 0,
		     !ingressPacket ? num_pkts : 0, !ingressPacket ? pkt_len : 0);
#endif
  };

  inline void incICMPStats(bool is_icmpv6, u_int32_t num_pkts, u_int8_t icmp_type, u_int8_t icmp_code, bool sent) {
    if(is_icmpv6)
      icmp_v6.incStats(num_pkts, icmp_type, icmp_code, sent, NULL);
    else
      icmp_v4.incStats(num_pkts, icmp_type, icmp_code, sent, NULL);
  };
  inline void incLocalStats(u_int num_pkts, u_int pkt_len, bool localsender, bool localreceiver) {
    localStats.incStats(num_pkts, pkt_len, localsender, localreceiver);
  };
  inline void incnDPIFlows(u_int16_t l7_protocol)    { ndpiStats->incFlowsStats(l7_protocol); }

  inline void incDSCPStats(u_int8_t ds, u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t rcvd_packets, u_int64_t rcvd_bytes) { 
    dscpStats->incStats(ds, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes); 
  }

  virtual void sumStats(TcpFlowStats *_tcpFlowStats, EthStats *_ethStats,
			LocalTrafficStats *_localStats, nDPIStats *_ndpiStats,
			PacketStats *_pktStats, TcpPacketStats *_tcpPacketStats,
			ProtoStats *_discardedProbingStats, DSCPStats *_dscpStats,
			SyslogStats *_syslogStats) const;
  inline DB *getDB() const         { return db;                  };
  inline EthStats* getStats()      { return(&ethStats);          };
  inline int get_datalink()        { return(pcap_datalink_type); };
  inline void set_datalink(int l)  { pcap_datalink_type = l;     };
  bool isRunning() const;
  inline bool isTrafficMirrored()           const { return is_traffic_mirrored;            };
  inline bool showDynamicInterfaceTraffic() const { return show_dynamic_interface_traffic; };
  inline bool discardProbingTraffic()       const { return discard_probing_traffic;        };
  inline bool flowsOnlyInterface()          const { return flows_only_interface;           };
  void updateIPReassignment(bool enabled);
  void updateTrafficMirrored();
  void updateDynIfaceTrafficPolicy();
  void updateFlowDumpDisabled();
  void updateLbdIdentifier();
  void updateDiscardProbingTraffic();
  void updateFlowsOnlyInterface();
  bool restoreHost(char *host_ip, VLANid vlan_id);
  void checkHostsToRestore();
  u_int printAvailableInterfaces(bool printHelp, int idx, char *ifname, u_int ifname_len);
  void findFlowHosts(VLANid vlan_id, u_int16_t observation_domain_id,
		     Mac *src_mac, IpAddress *_src_ip, Host **src,
		     Mac *dst_mac, IpAddress *_dst_ip, Host **dst);
  virtual Flow* findFlowByKeyAndHashId(u_int32_t key, u_int hash_id, AddressTree *allowed_hosts);
  virtual Flow* findFlowByTuple(VLANid vlan_id,
				u_int16_t observation_domain_id,
				IpAddress *src_ip,  IpAddress *dst_ip,
				u_int16_t src_port, u_int16_t dst_port,
				u_int8_t l4_proto,
				AddressTree *allowed_hosts) const;
  bool findHostsByName(lua_State* vm, AddressTree *allowed_hosts, char *key);
  bool findHostsByMac(lua_State* vm, u_int8_t *mac);
  bool dissectPacket(u_int32_t bridge_iface_idx,
		     bool ingressPacket,
		     u_int8_t *sender_mac, /* Non NULL only for NFQUEUE interfaces */
		     const struct pcap_pkthdr *h, const u_char *packet,
		     u_int16_t *ndpiProtocol,
		     Host **srcHost, Host **dstHost, Flow **flow);
  bool processPacket(u_int32_t bridge_iface_idx,
		     bool ingressPacket,
		     const struct bpf_timeval *when,
		     const u_int64_t time,
		     struct ndpi_ethhdr *eth,
		     VLANid vlan_id,
		     struct ndpi_iphdr *iph,
		     struct ndpi_ipv6hdr *ip6,
		     u_int16_t ip_offset,
		     u_int32_t len_on_wire,
		     const struct pcap_pkthdr *h,
		     const u_char *packet,
		     u_int16_t *ndpiProtocol,
		     Host **srcHost, Host **dstHost, Flow **flow);
  void processInterfaceStats(sFlowInterfaceStats *stats);
  void getActiveFlowsStats(nDPIStats *stats, FlowStats *status_stats, AddressTree *allowed_hosts, Host *h, Paginator *p, lua_State *vm, bool only_traffic_stats);
  virtual u_int32_t periodicStatsUpdateFrequency() const;
  void periodicStatsUpdate();
  u_int64_t purgeQueuedIdleEntries();
  struct timeval periodicUpdateInitTime() const;
  virtual u_int32_t getFlowMaxIdle();

  virtual void lua(lua_State* vm);
#ifdef NTOPNG_PRO
  void luaTrafficMapHostStats(lua_State* vm, AddressTree *allowed_hosts, char *host_ip, VLANid vlan_id);
#endif
  void luaScore(lua_State* vm);
  void luaAlertedFlows(lua_State* vm);
  void luaAnomalies(lua_State* vm);
  void luaNdpiStats(lua_State* vm, bool diff = false);
  void luaPeriodicityFilteringMenu(lua_State* vm);
  void luaServiceFilteringMenu(lua_State* vm);
  void luaPeriodicityStats(lua_State* vm, IpAddress *ip_address, VLANid vlan_id, u_int16_t host_pool_id, 
                            bool unicast, u_int32_t first_seen, u_int16_t filter_ndpi_proto);
  void luaServiceMap(lua_State* vm, IpAddress *ip_address, VLANid vlan_id, u_int16_t host_pool_id, 
                      bool unicast, u_int32_t first_seen, u_int16_t filter_ndpi_proto);
  void luaSubInterface(lua_State *vm);
  void luaServiceMapStatus(lua_State *vm);
  inline float getThroughputBps()            { return bytes_thpt.getThpt(); };
  inline float getThroughputPps()            { return pkts_thpt.getThpt();  };
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  inline ServiceMap* getServiceMap()         { return(sMap);           };
  inline bool isServiceMapEnabled()          { return(sMap ? true : false); };
  inline void flushServiceMap()              { if(sMap) sMap->flush(); };
  inline PeriodicityMap* getPeriodicityMap() { return(pMap);           };
  inline bool isPeriodicityMapEnabled()      { return(pMap ? true : false); };
  inline void flushPeriodicityMap()          { if(pMap) pMap->flush(); };
  void updateFlowPeriodicity(Flow *f);
  void updateServiceMap(Flow *f);  
#endif
  void lua_hash_tables_stats(lua_State* vm);
  void lua_periodic_activities_stats(lua_State* vm);
  virtual void lua_queues_stats(lua_State* vm);
  void getnDPIProtocols(lua_State *vm, ndpi_protocol_category_t filter, bool skip_critical);

  int getActiveHostsList(lua_State* vm,
			 u_int32_t *begin_slot,
			 bool walk_all,
			 u_int8_t bridge_iface_idx,
			 AddressTree *allowed_hosts,
			 bool host_details, LocationPolicy location,
			 char *countryFilter, char *mac_filter,
			 VLANid vlan_id, OSType osFilter,
			 u_int32_t asnFilter, int16_t networkFilter,
			 u_int16_t pool_filter, bool filtered_hosts,
			 bool blacklisted_hosts, bool hide_top_hidden,
			 u_int8_t ipver_filter, int proto_filter,
			 TrafficType traffic_type_filter, bool tsLua,
			 bool anomalousOnly, bool dhcpOnly,
			 const AddressTree * const cidr_filter,
			 char *sortColumn, u_int32_t maxHits,
			 u_int32_t toSkip, bool a2zSortOrder);
  int getActiveASList(lua_State* vm, const Paginator *p, bool diff = false);
  int getActiveOSList(lua_State* vm, const Paginator *p);
  int getActiveCountriesList(lua_State* vm, const Paginator *p);
  int getActiveVLANList(lua_State* vm,
			char *sortColumn, u_int32_t maxHits,
			u_int32_t toSkip, bool a2zSortOrder,
			DetailsLevel details_level);
  int getActiveMacList(lua_State* vm,
		       u_int32_t *begin_slot,
		       bool walk_all,
		       u_int8_t bridge_iface_idx,
		       bool sourceMacsOnly,
		       const char *manufacturer,
		       char *sortColumn, u_int32_t maxHits,
		       u_int32_t toSkip, bool a2zSortOrder,
		       u_int16_t pool_filter, u_int8_t devtype_filter,
		       u_int8_t location_filter, time_t min_first_seen);
  int getActiveMacManufacturers(lua_State* vm,
				u_int8_t bridge_iface_idx,
				bool sourceMacsOnly,
				u_int32_t maxHits, u_int8_t devtype_filter,
				u_int8_t location_filter);
  bool getActiveMacHosts(lua_State* vm, const char *mac);
  int getActiveDeviceTypes(lua_State* vm,
			   u_int8_t bridge_iface_idx,
			   bool sourceMacsOnly,
			   u_int32_t maxHits, const char *manufacturer,
			   u_int8_t location_filter);
  int getMacsIpAddresses(lua_State *vm, int idx);
  void getFlowsStats(lua_State* vm);
  void getNetworkStats(lua_State* vm, u_int16_t network_id, AddressTree *allowed_hosts, bool diff = false) const;
  void getNetworksStats(lua_State* vm, AddressTree *allowed_hosts, bool diff = false) const;
  int getFlows(lua_State* vm,
	       u_int32_t *begin_slot,
	       bool walk_all,
	       AddressTree *allowed_hosts,
	       Host *host,
	       Paginator *p);
  int getFlowsTraffic(lua_State* vm,
	       u_int32_t *begin_slot,
	       bool walk_all,
	       AddressTree *allowed_hosts,
	       Host *host,
	       Paginator *p);
  int getFlowsGroup(lua_State* vm,
		AddressTree *allowed_hosts,
		Paginator *p,
		const char *groupColumn);
  int dropFlowsTraffic(AddressTree *allowed_hosts, Paginator *p);

  virtual void purgeIdle(time_t when, bool force_idle = false, bool full_scan = false);
  u_int purgeIdleFlows(bool force_idle, bool full_scan);
  u_int purgeIdleHosts(bool force_idlei, bool full_scan);
  u_int purgeIdleMacsASesCountriesVLANs(bool force_idle, bool full_scan);

  /* Overridden in ViewInterface.cpp */
  virtual u_int64_t getNumPackets();
  virtual u_int64_t getNumBytes();
  virtual u_int64_t getNumDroppedAlerts();
  virtual void      updatePacketsStats() { };
  virtual u_int32_t getNumDroppedPackets() { return 0; };
  virtual u_int     getNumPacketDrops();
  virtual u_int64_t getNumNewFlows();
  virtual u_int64_t getNumDiscardedProbingPackets() const;
  virtual u_int64_t getNumDiscardedProbingBytes()   const;
  virtual u_int     getNumFlows();
  u_int             getNumL2Devices();
  u_int             getNumHosts();
  u_int             getNumLocalHosts();
  u_int             getNumMacs();
  u_int             getNumHTTPHosts();

  inline u_int64_t  getNumPacketsSinceReset()     { return getNumPackets() - getCheckPointNumPackets(); }
  inline u_int64_t  getNumBytesSinceReset()       { return getNumBytes() - getCheckPointNumBytes(); }
  inline u_int64_t  getNumPacketDropsSinceReset() { return getNumPacketDrops() - getCheckPointNumPacketDrops(); }
  inline u_int64_t  getNumDroppedAlertsSinceReset() { return getNumDroppedAlerts() - getCheckPointDroppedAlerts(); }
  inline u_int64_t  getNumDiscProbingPktsSinceReset() const {
    return getNumDiscardedProbingPackets() - getCheckPointNumDiscardedProbingPackets();
  };
  inline u_int64_t getNumDiscProbingBytesSinceReset() const {
    return getNumDiscardedProbingBytes() - getCheckPointNumDiscardedProbingBytes();
  }

  virtual void runHousekeepingTasks();
  void runShutdownTasks();
  VLAN* getVLAN(VLANid vlanId, bool create_if_not_present, bool is_inline_call);
  AutonomousSystem *getAS(IpAddress *ipa, bool create_if_not_present, bool is_inline_call);
  OperatingSystem *getOS(OSType os, bool create_if_not_present, bool is_inline_call);
  Country* getCountry(const char *country_name, bool create_if_not_present, bool is_inline_call);
  virtual Mac*  getMac(u_int8_t _mac[6], bool create_if_not_present, bool is_inline_call);
  virtual Host* getHost(char *host_ip, VLANid vlan_id, u_int16_t observationPointId, bool is_inline_call);
  bool getHostInfo(lua_State* vm, AddressTree *allowed_hosts, char *host_ip, VLANid vlan_id);
  void findPidFlows(lua_State *vm, u_int32_t pid);
  void findProcNameFlows(lua_State *vm, char *proc_name);
  void addAllAvailableInterfaces();
  inline bool idle() { return(is_idle); }
  inline u_int16_t getMTU()         { return(ifMTU);                               }
  virtual u_int getPacketOverhead() { return 24 /* 8 Preamble + 4 CRC + 12 IFG */; }
  inline void setIdleState(bool new_state)         { is_idle = new_state;  };
  inline StatsManager  *getStatsManager()          { return statsManager;  };
  AlertsQueue* getAlertsQueue() const;
  bool alert_store_query(lua_State *vm, const char * const sql);

  void listHTTPHosts(lua_State *vm, char *key);
#ifdef NTOPNG_PRO
  void refreshL7Rules();
  void refreshShapers();
  inline L7Policer* getL7Policer()                     { return(policer);                }
  inline FlowInterfacesStats* getFlowInterfacesStats() { return(flow_interfaces_stats);  }
#endif
  inline HostPools* getHostPools()                     { return(host_pools);    }
  inline void reloadHostPools()     { if(host_pools) host_pools->reloadPools(); }

  bool registerLiveCapture(struct ntopngLuaContext * const luactx, int *id);
  bool deregisterLiveCapture(struct ntopngLuaContext * const luactx);
  void dumpLiveCaptures(lua_State* vm);
  bool stopLiveCapture(int capture_id);
#ifdef NTOPNG_PRO
#ifdef HAVE_NEDGE
  void updateHostsL7Policy(u_int16_t host_pool_id);
  void updateFlowsL7Policy();
#endif
  void resetPoolsStats(u_int16_t pool_filter);
#endif
  inline void luaHostPoolsStats(lua_State *vm)           { if (host_pools) host_pools->luaStats(vm);           };
  void refreshHostPools();
  inline u_int16_t getHostPool(Host *h) { if(h && host_pools) return host_pools->getPool(h); return NO_HOST_POOL_ID; };
  inline u_int16_t getHostPool(Mac *m)  { if(m && host_pools) return host_pools->getPool(m); return NO_HOST_POOL_ID; };

  void loadScalingFactorPrefs();
  void getnDPIFlowsCount(lua_State *vm);

  inline void setBridgeLanInterfaceId(u_int32_t v) { bridge_lan_interface_id = v;     };
  inline u_int32_t getBridgeLanInterfaceId()       { return(bridge_lan_interface_id); };
  inline void setBridgeWanInterfaceId(u_int32_t v) { bridge_wan_interface_id = v;     };
  inline u_int32_t getBridgeWanInterfaceId()       { return(bridge_wan_interface_id); };
  inline HostHash* get_hosts_hash()                { return(hosts_hash);              }
  inline bool is_bridge_interface()                { return(bridge_interface);        }
  inline const char* getLocalIPAddresses()         { return(ip_addresses.c_str());    }
  void addInterfaceAddress(char * const addr);
  void addInterfaceNetwork(char * const net, char * addr);
  bool isInterfaceNetwork(const IpAddress * const ipa, int network_bits) const;
  inline int exec_sql_query(lua_State *vm, char *sql, bool limit_rows, bool wait_for_db_created = true) {
#ifdef HAVE_MYSQL
    if(dynamic_cast<MySQLDB*>(db) != NULL)
      return ((MySQLDB*)db)->exec_sql_query(vm, sql, limit_rows, wait_for_db_created);
#endif
    return(-1);
  };
  NetworkStats* getNetworkStats(u_int8_t networkId) const;
  void allocateStructures();
  void getsDPIStats(lua_State *vm);
#ifdef NTOPNG_PRO
  void updateFlowProfiles();
#ifndef HAVE_NEDGE
  inline FlowProfile* getFlowProfile(Flow *f)  { return(flow_profiles ? flow_profiles->getFlowProfile(f) : NULL);           }
  inline bool checkProfileSyntax(char *filter) { return(flow_profiles ? flow_profiles->checkProfileSyntax(filter) : false); }

  inline bool checkSubInterfaceSyntax(char *filter) { return(sub_interfaces ? sub_interfaces->checkSyntax(filter) : false); }
#endif

  bool passShaperPacket(TrafficShaper *a_shaper, TrafficShaper *b_shaper, struct pcap_pkthdr *h);
  void initL7Policer();
#endif

  void getFlowsStatus(lua_State *vm);
  inline void startDBLoop() { if(db) db->startDBLoop(); };
  inline void incDBNumDroppedFlows(DB *dumper, u_int num = 1) { if(dumper) dumper->incNumDroppedFlows(num); };
#ifdef NTOPNG_PRO
  void updateBehaviorStats(const struct timeval *tv);

  void getFlowDevices(lua_State *vm) {
    if(flow_interfaces_stats) flow_interfaces_stats->luaDeviceList(vm); else lua_newtable(vm);
  };
  void getFlowDeviceInfo(lua_State *vm, u_int32_t deviceIP) {
    if(flow_interfaces_stats) flow_interfaces_stats->luaDeviceInfo(vm, deviceIP, this); else lua_newtable(vm);
  };
#endif
  inline void getSFlowDevices(lua_State *vm) {
    if(interfaceStats) interfaceStats->luaDeviceList(vm); else lua_newtable(vm);
  };
  inline void getSFlowDeviceInfo(lua_State *vm, u_int32_t deviceIP) {
    if(interfaceStats) interfaceStats->luaDeviceInfo(vm, deviceIP); else lua_newtable(vm);
  };
  int updateHostTrafficPolicy(AddressTree* allowed_networks, char *host_ip, u_int16_t host_vlan);

  virtual void reloadCompanions() {};
  void reloadHideFromTop(bool refreshHosts=true);
  void requestGwMacsReload() { gw_macs_reload_requested = true; };
  void reloadGwMacs();

  inline bool serializeLbdHostsAsMacs()             { return(lbd_serialize_by_mac); }
  void checkReloadHostsBroadcastDomain();
  inline bool reloadHostsBroadcastDomain()          { return reload_hosts_bcast_domain; }
  void reloadHostsBlacklist();
  void checkNetworksAlerts(vector<ScriptPeriodicity> *p, lua_State* vm);
  void checkInterfaceAlerts(vector<ScriptPeriodicity> *p, lua_State* vm);
  bool isHiddenFromTop(Host *host);
  virtual bool areTrafficDirectionsSupported() { return(false); };

  inline bool isView()                const { return is_view;             };
  inline ViewInterface*    viewedBy() const { return viewed_by;           };
  inline u_int8_t       getViewedId() const { return viewed_interface_id; };
  inline bool isViewed()              const { return viewedBy() != NULL;  };
  /*
    Method called by a view interface on all its viewed interfaces.
    The view passes to this method both its pointer and the viewed interface id,
    that is, a numeric identifier for the viewed interface inside the view interface.
   */
  inline void setViewed(ViewInterface *view_iface, u_int8_t _viewed_interface_id) {
    viewed_by = view_iface;
    viewed_interface_id = _viewed_interface_id;
  };

  bool getMacInfo(lua_State* vm, char *mac);
  bool resetMacStats(lua_State* vm, char *mac, bool delete_data);
  bool setMacDeviceType(char *strmac, DeviceType dtype, bool alwaysOverwrite);
  bool getASInfo(lua_State* vm, u_int32_t asn);
  bool getOSInfo(lua_State* vm, OSType os_type);
  bool getCountryInfo(lua_State* vm, const char *country);
  bool getVLANInfo(lua_State* vm, VLANid vlan_id);
  inline void incNumHosts(bool local) { if(local) numLocalHosts++; numHosts++; };
  inline void decNumHosts(bool local) { if(local) numLocalHosts--; numHosts--; };
  inline void incNumL2Devices()       { numL2Devices++; }
  inline void decNumL2Devices()       { numL2Devices--; }
  inline u_int32_t getScalingFactor()       const { return(scalingFactor); }
  inline void setScalingFactor(u_int32_t f) { scalingFactor = f;     }
  virtual bool isSampledTraffic()           const { return((scalingFactor == 1) ? false : true); }
#ifdef NTOPNG_PRO
  virtual bool getCustomAppDetails(u_int32_t remapped_app_id, u_int32_t *const pen, u_int32_t *const app_field, u_int32_t *const app_id) { return false; };
  virtual void addToNotifiedInformativeCaptivePortal(u_int32_t client_ip) { ; };
  virtual void addIPToLRUMatches(u_int32_t client_ip, u_int16_t user_pool_id, char *label) { ; };
#endif

  inline char* mdnsResolveIPv4(u_int32_t ipv4addr /* network byte order */,
			       char *buf, u_int buf_len, u_int timeout_sec = 2) {
    if(mdns)
      return(mdns->resolveIPv4(ipv4addr, buf, buf_len, timeout_sec));
    else {
      buf[0] = '\0';
      return(buf);
    }
  }

  inline void mdnsSendAnyQuery(char *targetIPv4, char *query) {
    if(mdns) mdns->sendAnyQuery(targetIPv4, query);
  }

  inline bool mdnsQueueResolveIPv4(u_int32_t ipv4addr, bool alsoUseGatewayDNS) {
    return(mdns ? mdns->queueResolveIPv4(ipv4addr, alsoUseGatewayDNS) : false);
  }

  inline void mdnsFetchResolveResponses(lua_State* vm, int32_t timeout_sec = 2) {
    if(mdns) mdns->fetchResolveResponses(vm, timeout_sec);
  }

  inline bool isSubInterface()                { return(is_dynamic_interface);            };
  void setSubInterface(FlowHashingEnum mode, u_int64_t criteria);
  bool isLocalBroadcastDomainHost(Host * const h, bool is_inline_call);
  inline MDNS* getMDNS() { return(mdns); }
  inline NetworkDiscovery* getNetworkDiscovery() { return(discovery); }
  inline void incPoolNumHosts(u_int16_t id, bool is_inline_call) {
    if (host_pools) host_pools->incNumHosts(id, is_inline_call);
  };
  inline void decPoolNumHosts(u_int16_t id, bool is_inline_call) {
    if (host_pools) host_pools->decNumHosts(id, is_inline_call);
  };
  inline void incPoolNumL2Devices(u_int16_t id, bool is_inline_call) {
    if (host_pools) host_pools->incNumL2Devices(id, is_inline_call);
  };
  inline void decPoolNumL2Devices(u_int16_t id, bool is_inline_call) {
    if (host_pools) host_pools->decNumL2Devices(id, is_inline_call);
  };
  Host* findHostByIP(AddressTree *allowed_hosts, char *host_ip, VLANid vlan_id, u_int16_t observationPointId);
#ifdef HAVE_NINDEX
  NIndexFlowDB* getNindex();
#endif
  TimeseriesExporter* getInfluxDBTSExporter();
  TimeseriesExporter* getRRDTSExporter();

  inline uint32_t getMaxSpeed() const      { return(ifSpeed);     }
  inline bool isLoopback() const           { return(is_loopback); }
  inline bool isGwMacConfigured() const    { return(gw_macs->getNumEntries() > 0); }
  inline bool isGwMac(u_int8_t a[6]) const { return(isGwMacConfigured() && gw_macs->get(a, false) != NULL); }
  inline bool isInterfaceMac(u_int8_t a[6]) const { return(memcmp(a, ifMac, sizeof(ifMac)) == 0); }

  virtual bool read_from_pcap_dump()      const { return(false); };
  virtual bool read_from_pcap_dump_done() const { return(false); };
  virtual void set_read_from_pcap_dump_done()   { ; };
  /*
    Issue a request for user scripts reload. This is called by ntopng when user scripts should be reloaded,
    e.g., after a configuration change.
   */
  virtual void updateDirectionStats()        { ; }
  void reloadDhcpRanges();

  /* Used to give the interface a new check loader to be used */
  void reloadFlowChecks(FlowChecksLoader *fcbl);
  void reloadHostChecks(HostChecksLoader *hcbl);
  
  inline bool hasConfiguredDhcpRanges()      { return(dhcp_ranges && !dhcp_ranges->last_ip.isEmpty()); };
  inline bool isFlowDumpDisabled()           { return(flow_dump_disabled); }
  inline struct ndpi_detection_module_struct* initnDPIStruct();
  bool isInDhcpRange(IpAddress *ip);
  void getPodsStats(lua_State* vm);
  void getContainersStats(lua_State* vm, const char *pod_filter);
  bool enqueueFlowToCompanion(ParsedFlow * const pf, bool skip_loopback_traffic);
  bool dequeueFlowFromCompanion(ParsedFlow ** pf);

#ifdef PROFILING
  inline void profiling_section_enter(const char *label, int id) { PROFILING_SECTION_ENTER(label, id); };
  inline void profiling_section_exit(int id) { PROFILING_SECTION_EXIT(id); };
#endif

  void incNumAlertedFlows(Flow *f, AlertLevel severity);
  void decNumAlertedFlows(Flow *f, AlertLevel severity);
  virtual u_int64_t getNumActiveAlertedFlows()      const;
  virtual u_int64_t getNumActiveAlertedFlows(AlertLevelGroup alert_level_group) const;
  void incNumAlertsEngaged(AlertEntity alert_entity);
  void decNumAlertsEngaged(AlertEntity alert_entity);
  void incNumDroppedAlerts(AlertEntity alert_entity);
  inline void incNumWrittenAlerts()			  { num_written_alerts++; }
  inline void incNumAlertsQueries()			  { num_alerts_queries++; }
  inline u_int64_t getNumWrittenAlerts()		  { return(num_written_alerts); }
  inline u_int64_t getNumAlertsQueries()		  { return(num_alerts_queries); }
  void walkAlertables(AlertEntity alert_entity, const char *entity_value,
		      AddressTree *allowed_nets, alertable_callback *callback, void *user_data);
  void getEngagedAlerts(lua_State *vm, AlertEntity alert_entity, const char *entity_value, AlertType alert_type,
			AlertLevel alert_severity, AlertRole role_filter, AddressTree *allowed_nets);

  /* unlockExternalAlertable must be called after use whenever a non-null reference is returned */
  AlertableEntity* lockExternalAlertable(AlertEntity entity, const char *entity_val, bool create_if_missing);
  void unlockExternalAlertable(AlertableEntity *entity);

  virtual bool reproducePcapOriginalSpeed() const         { return(false);             }
  u_int32_t getNumEngagedAlerts() const;
  void luaNumEngagedAlerts(lua_State *vm) const;
  void releaseAllEngagedAlerts();

  virtual void flowAlertsDequeueLoop(); /* Body of the loop that dequeues flows for the execution of user script hooks */
  virtual void hostAlertsDequeueLoop(); /* Same as above but for hosts */
  
  virtual void dumpFlowLoop(); /* Body of the loop that dequeues flows for the database dump */
  void incNumQueueDroppedFlows(u_int32_t num);
  /*
    Dequeues enqueued flows to dump them to database
   */
  u_int64_t dequeueFlowsForDump(u_int idle_flows_budget, u_int active_flows_budget);

  void execProtocolDetectedChecks(Flow *f);
  void execPeriodicUpdateChecks(Flow *f);
  void execFlowEndChecks(Flow *f);
  void execHostChecks(Host *h);
  
  inline void incHostAnomalies(u_int32_t local, u_int32_t remote) {
    tot_num_anomalies.local_hosts += local, tot_num_anomalies.remote_hosts += remote;
  };
  
  /*
    Dequeues enqueued flows to execute user script checks.
    Budgets indicate how many flows should be dequeued (if available) to perform protocol detected, active,
    and idle checks.
   */
  u_int64_t dequeueFlowAlertsFromChecks(u_int budget);
  inline FlowChecksExecutor* getFlowCheckExecutor() { return(flow_checks_executor); }

  /*
    Same as above but for hosts */
  u_int64_t dequeueHostAlertsFromChecks(u_int budget);
  inline HostChecksExecutor* getHostCheckExecutor() { return(host_checks_executor); }
  HostCheck *getCheck(HostCheckID t);

  void incObservationPointIdFlows(u_int16_t pointId, u_int32_t tot_bytes);

  inline bool hasObservationPointId(u_int16_t pointId) {
    /* This is work in progress and it needs to be locked when read */
    return((observationPoints.find(pointId) == observationPoints.end()) ? false : true);
  }
  
  void getObservationPoints(lua_State* vm);
  inline bool haveObservationPointsDefined()    { return(observationPoints.size() == 0 ? false : true); }
  inline u_int16_t getFirstObservationPointId() { return(observationPoints.size() == 0 ? 0 : observationPoints.begin()->first); }
};

#endif /* _NETWORK_INTERFACE_H_ */
