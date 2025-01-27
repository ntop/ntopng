/*
 *
 * (C) 2013-25 - ntop.org
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
class ObservationPoint;
class ObservationPointHash;
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
class NetworkInterfacePro;
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
#ifdef HAVE_NEDGE
  std::map<u_int32_t, InterfaceLocation> bridge_interface_id_to_location;
#endif
  u_int32_t num_alerts_engaged_notice[ALERT_ENTITY_MAX_NUM_ENTITIES],
    num_alerts_engaged_warning[ALERT_ENTITY_MAX_NUM_ENTITIES],
    num_alerts_engaged_error[ALERT_ENTITY_MAX_NUM_ENTITIES],
    num_alerts_engaged_critical[ALERT_ENTITY_MAX_NUM_ENTITIES],
    num_alerts_engaged_emergency[ALERT_ENTITY_MAX_NUM_ENTITIES], flow_serial;
  std::atomic<u_int64_t> alert_serial;
  /* Counters for active alerts. Changed by multiple concurrent threads */
  std::atomic<u_int64_t>
  num_active_alerted_flows_notice; /* Counts all flow alerts with severity
				      <= notice  */
  std::atomic<u_int64_t>
  num_active_alerted_flows_warning; /* Counts all flow alerts with severity
				       == warning */
  std::atomic<u_int64_t>
  num_active_alerted_flows_error; /* Counts all flow alerts with severity >=
				     error   */
  std::atomic<u_int32_t> num_active_probes; /* Count active ZMQ probes */
  u_int32_t num_host_dropped_alerts, num_flow_dropped_alerts,
    num_other_dropped_alerts, last_purge_idle;
  u_int64_t num_written_alerts, num_alerts_queries, score_as_cli, score_as_srv;
  u_int64_t num_new_flows;
  time_t last_ndpi_reload;
  bool ndpi_cleanup_needed;
  struct {
    u_int32_t local_hosts, remote_hosts;
  } tot_num_anomalies;
  AlertsQueue *alertsQueue;
#if defined(NTOPNG_PRO)
  PeriodicityMap *pMap;
  ServiceMap *sMap;
  ACLFlow *acl_flow;
#endif

  UsedPorts usedPorts;

  struct ndpi_detection_module_struct *ndpi_struct, *ndpi_struct_shadow;
  bool ndpiReloadInProgress;

  /* The executor is per-interfaces, and uses the loader to configure itself and
   * execute flow checks */
  FlowChecksExecutor *flow_checks_executor, *prev_flow_checks_executor;
  HostChecksExecutor *host_checks_executor, *prev_host_checks_executor;

#if defined(NTOPNG_PRO)
  /* Logic for detecting packet protocol storms */
  u_int32_t dhcp_last_sec_pkts, last_sec_epoch;

  time_t nextMinPeriodicUpdate, next5MinPeriodicUpdate;
  /* Behavioural analysis regarding the interface */
  BehaviorAnalysis *score_behavior, *traffic_tx_behavior, *traffic_rx_behavior;
#endif
  MostVisitedList *top_sites;

  /* Flows queues waiting to be dumped */
  SPSCQueue<Flow *> *idleFlowsToDump, *activeFlowsToDump;
  Condvar dump_condition; /* Condition variable used to wait when no flows have
                             been enqueued for dump */

  /* CustomScript VMs */
  LuaEngine *customFlowLuaScript_proto, /* Called when nDPI has detected the protocol */
    *customFlowLuaScript_periodic, /* Called periodically on flows    */
    *customFlowLuaScript_end;      /* Called when the flow ends       */
  LuaEngine *customHostLuaScript; /* Called periodically on hosts */

  /* Queues for the execution of flow user scripts */
  SPSCQueue<FlowAlert *> *flowAlertsQueue;
  SPSCQueue<HostAlertReleasedPair> *hostAlertsQueue;

  /*
    Flag to indicate whether a flow JSON should be dumped along with the flow.
    Flow JSON contain additional fields not placed inside database columns.
  */
  bool flows_dump_json;

  /* External alerts contain alertable entities other than
   * host/interface/network which are dynamically allocated when an alert for
   * them occurs. A lock is necessary to guard the insert/delete operations from
   * lookup operations requested from the GUI and to ensure that a delete
   * operation does generate a use-after-free. */
  std::map<std::pair<AlertEntity, std::string>, InterfaceMemberAlertableEntity *> external_alerts;
  Mutex external_alerts_lock;

  RoundTripStats *download_stats, *upload_stats;

  bool is_view; /* Whether this is a view interface */
  ViewInterface *viewed_by; /* Whether this interface is 'viewed' by a ViewInterface */
  u_int8_t viewed_interface_id; /* When this is a 'viewed' interface, this id
                                   represents a unique interface identifier
                                   inside the view */

  /* Disaggregations */
  u_int16_t numSubInterfaces;
  std::set<u_int32_t> flowHashingIgnoredInterfaces;
  FlowHashingEnum flowHashingMode;
  std::map<u_int64_t, NetworkInterface *> flowHashing;

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
  bool ip_reassignment_alerts_enabled;
  
  /* Live Capture */
  Mutex active_captures_lock;
  u_int8_t num_live_captures;
  NtopngLuaContext *live_captures[MAX_NUM_PCAP_CAPTURES];
  static bool matchLiveCapture(NtopngLuaContext *const luactx,
                               const struct pcap_pkthdr *const h,
                               const u_char *const packet, Flow *const f);
  void deliverLiveCapture(const struct pcap_pkthdr *const h,
                          const u_char *const packet, Flow *const f);

  string ip_addresses;
  AddressTree interface_networks;
  int id;
  bool bridge_interface;

  bool is_dynamic_interface;           /* Whether this is a dynamic interface */
  bool show_dynamic_interface_traffic; /* Show traffic of this dynamic interface
                                        */
  bool push_host_filters; /* Push alerted hosts to pf_ring via Redis queue */
  u_int64_t dynamic_interface_criteria; /* Criteria identifying this dynamic
                                           interface */
  FlowHashingEnum
  dynamic_interface_mode; /* Mode (e.g., Probe IP, VLAN ID, etc */
  NetworkInterface *dynamic_interface_master; /* Main interface */

  bool is_traffic_mirrored, is_loopback;
  bool flows_only_interface; /* Only allocates flows for the interface (e.g., no
                                hosts, ases, etc) */
  bool is_smart_recording_enabled;
  char *smart_recording_instance_name;
#ifdef NTOPNG_PRO
  L7Policer *policer;

#if defined(HAVE_KAFKA)
  KafkaProducer *kafka;
#endif

#ifndef HAVE_NEDGE
  FlowProfiles *flow_profiles, *shadow_flow_profiles;
  SubInterfaces *sub_interfaces;
#endif
  CustomAppStats *custom_app_stats;
  FlowInterfacesStats *flow_interfaces_stats;
  NetworkInterfacePro *network_interface_pro;
#endif
  EthStats ethStats;
  std::map<u_int32_t, u_int64_t> ip_mac; /* IP (network byte order) <-> MAC
                                            association [2 bytes are unused] */
  u_int32_t arp_requests, arp_replies;
  ICMPstats icmp_v4, icmp_v6;
  LocalTrafficStats localStats;
  int pcap_datalink_type; /**< Datalink type of pcap. */
  pthread_t pollLoop, flowDumpLoop /* Thread for the database dump of flows */,
    flowChecksLoop /* Thread for the execution of flow user script hooks */,
    hostChecksLoop /* Thread for the execution of host user script hooks */
    ;
  Condvar flow_checks_condvar, host_checks_condvar;
  bool pollLoopCreated, flowDumpLoopCreated, flowAlertsDequeueLoopCreated,
    hostAlertsDequeueLoopCreated;
  bool has_too_many_hosts, has_too_many_flows, mtuWarningShown;
  bool flow_dump_disabled_by_user, flow_dump_disabled_by_backend;
  u_int32_t ifSpeed, scalingFactor;
  u_int32_t numL2Devices;
  std::atomic<u_int64_t> totalNumHosts;
  std::atomic<u_int64_t> numTotalRxOnlyHosts; /* subset of numTotalRxOnlyHosts that have received
			   but never sent any traffic */
  std::atomic<u_int64_t> numLocalHosts;
  std::atomic<u_int64_t> numLocalRxOnlyHosts; /* subset of numLocalHosts that have received but
			   never sent any traffic */
  /* Those will hold counters at checkpoints */
  u_int64_t checkpointPktCount, checkpointBytesCount, checkpointPktDropCount,
    checkpointDroppedAlertsCount;
  u_int64_t 
    checkpointTrafficSent, 
    checkpointTrafficRcvd,
    checkpointPacketsSent,
    checkpointPacketsRcvd;
  u_int16_t ifMTU;
  int cpu_affinity; /**< Index of physical core where the network interface
                       works. */
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

  /* Observation Point */
  u_int16_t last_obs_point_id;
  ObservationPointHash *obs_hash; /**< Hash used to store Observation Point information. */

  /* Countries */
  CountriesHash *countries_hash;

  /* VLANs */
  VLANHash *vlans_hash; /**< Hash used to store VLAN information. */

  /* Hosts */
  HostHash *hosts_hash; /**< Hash used to store hosts information. */
  bool purge_idle_flows_hosts, inline_interface;
  DB *db;
  StatsManager *statsManager;
  AlertStore *alertStore;
  HostPools *host_pools;
  bool has_vlan_packets, has_ebpf_events, has_mac_addresses,
    has_seen_dhcp_addresses;
  bool has_seen_pods, has_seen_containers, has_external_alerts;
  time_t last_pkt_rcvd,
    last_pkt_rcvd_remote, /* Meaningful only for ZMQ interfaces */
    next_idle_flow_purge, next_idle_host_purge, next_idle_other_purge;
  bool running, shutting_down, is_idle;
  NetworkStats **networkStats; /* One stats entry per network defined (-m) */
  InterfaceStatsHash *interfaceStats;
  dhcp_range *dhcp_ranges, *dhcp_ranges_shadow;

  INTERFACE_PROFILING_DECLARE(32);

  void init(const char *interface_name);
  void deleteDataStructures();

  NetworkInterface *getDynInterface(u_int64_t criteria, bool parser_interface);
  Flow* getFlow(int32_t if_index, Mac *srcMac, Mac *dstMac, u_int16_t vlan_id,
                u_int16_t observation_domain_id, u_int32_t private_flow_id,
                u_int32_t deviceIP, u_int32_t inIndex, u_int32_t outIndex,
                const ICMPinfo *const icmp_info, IpAddress *src_ip,
                IpAddress *dst_ip, u_int16_t src_port, u_int16_t dst_port,
                u_int8_t l4_proto, bool *src2dst_direction, time_t first_seen,
                time_t last_seen, u_int32_t len_on_wire, bool *new_flow,
                bool create_if_missing, u_int8_t *view_cli_mac,
                u_int8_t *view_srv_mac);
  int sortHosts(u_int32_t *begin_slot, bool walk_all,
                struct flowHostRetriever *retriever, u_int8_t bridge_iface_idx,
                AddressTree *allowed_hosts, bool host_details,
                LocationPolicy location, char *countryFilter, char *mac_filter,
                u_int16_t vlan_id, OSType osFilter, u_int32_t asnFilter,
                int32_t networkFilter, u_int16_t pool_filter,
                bool filtered_hosts, bool blacklisted_hosts, bool anomalousOnly,
                bool dhcpOnly, const AddressTree *const cidr_filter,
                u_int8_t ipver_filter, int proto_filter,
                TrafficType traffic_type_filter, u_int32_t device_ip,
                char *sortColumn);
  int sortASes(struct flowHostRetriever *retriever, char *sortColumn);
  int sortObsPoints(struct flowHostRetriever *retriever, char *sortColumn);
  int sortCountries(struct flowHostRetriever *retriever, char *sortColumn);
  int sortVLANs(struct flowHostRetriever *retriever, char *sortColumn);
  int sortMacs(u_int32_t *begin_slot, bool walk_all,
               struct flowHostRetriever *retriever, u_int8_t bridge_iface_idx,
               bool sourceMacsOnly, const char *manufacturer, char *sortColumn,
               u_int16_t pool_filter, u_int8_t devtype_filter,
               u_int8_t location_filter, time_t min_first_seen);
  int sortFlows(u_int32_t *begin_slot, bool walk_all,
                struct flowHostRetriever *retriever, AddressTree *allowed_hosts,
                Host *host, Host *client, Host *server, char *flow_info,
                Paginator *p, const char *sortColumn);

  void addRedisSitesKey();
  void removeRedisSitesKey();

  void FillObsHash();

  bool isNumber(const char *str);
  bool checkIdle();
  bool checkPeriodicStatsUpdateTime(const struct timeval *tv);
  void topItemsCommit(const struct timeval *when);
  void checkMacIPAssociation(bool triggerEvent, u_char *_mac, u_int32_t ipv4,
                             Mac *host_mac);
  void checkDhcpIPRange(Mac *sender_mac, struct dhcp_packet *dhcp_reply,
                        u_int16_t vlan_id);
  void pollQueuedeCompanionEvents();
  bool getInterfaceBooleanPref(const char *pref_key,
                               bool default_pref_value) const;
  virtual void incEthStats(bool ingressPacket, u_int16_t proto,
                           u_int32_t num_pkts, u_int32_t num_bytes,
                           u_int pkt_overhead) {
    ethStats.incStats(ingressPacket, num_pkts, num_bytes, pkt_overhead);
    ethStats.incProtoStats(proto, num_pkts, num_bytes);
  };

  /*
    Dequeues alerted flows up to `budget` and executes `flow_lua_check` on each
    of them. The number of flows dequeued is returned.
  */
  u_int64_t dequeueFlowAlerts(u_int budget);

  u_int64_t dequeueHostAlerts(u_int budget); /* Same as above but for hosts */
  u_int16_t guessEthType(const u_char *p, u_int len, u_int8_t *is_ethernet);
  void loadProtocolsAssociations(struct ndpi_detection_module_struct *ndpi_str);

#ifdef NTOPNG_PRO
  void checkDHCPStorm(time_t when, u_int32_t num_pkts);
#endif
  void lua_push_ports(lua_State *vm,
		  HostsPorts *count,
		  u_int16_t protocol);
  void sort_hosts_details(lua_State *vm,
                          HostsPortsAnalysis *count,
                          u_int16_t protocol,
                          bool get_port);
  void sort_and_filter_flow_stats(lua_State *vm,
				  struct aggregated_stats *stats,
				  AnalysisCriteria filter_type);
  void build_lua_rsp(lua_State *vm, AggregatedFlowsStats *fs, u_int filter_type,
                     u_int32_t size, u_int *num, bool set_resp);
  void build_protocol_flow_stats_lua_rsp(lua_State *vm, AggregatedFlowsStats *fs,
                                         u_int32_t size, u_int *num);

public:
  /**
   * @brief A Constructor
   * @details Creating a new NetworkInterface with all instance variables set to
   * NULL.
   *
   * @return A new instance of NetworkInterface.
   */
  NetworkInterface();
  NetworkInterface(const char *name, const char *custom_interface_type = NULL);
  virtual ~NetworkInterface();

  bool initFlowChecksLoop(); /* Initialize the loop to dequeue flows for the
                                execution of user script hooks */
  bool initHostChecksLoop(); /* Same as above but for hosts */
  bool initFlowDump(u_int8_t num_dump_interfaces);
  u_int32_t getASesHashSize();
  u_int32_t getObsHashSize();
  u_int32_t getCountriesHashSize();
  u_int32_t getVLANsHashSize();
  u_int32_t getMacsHashSize();
  u_int32_t getHostsHashSize();
  virtual u_int32_t getFlowsHashSize();

  void updateSitesStats();
  void updateBroadcastDomains(u_int16_t vlan_id, const u_int8_t *src_mac,
                              const u_int8_t *dst_mac, u_int32_t src,
                              u_int32_t dst);

  virtual bool walker(u_int32_t *begin_slot, bool walk_all, WalkerType wtype,
                      bool (*walker)(GenericHashEntry *h, void *user_data,
                                     bool *entryMatched),
                      void *user_data);

  void checkDisaggregationMode();
  void incrVisitedWebSite(char *hostname);
  inline void incScoreValue(u_int16_t score_incr, bool as_client) {
    as_client ? score_as_cli += score_incr : score_as_srv += score_incr;
  };
  inline void decScoreValue(u_int16_t score_incr, bool as_client) {
    as_client ? score_as_cli -= score_incr : score_as_srv -= score_incr;
  };
  inline void setCPUAffinity(int core_id) { cpu_affinity = core_id; };
  inline void getIPv4Address(bpf_u_int32 *a, bpf_u_int32 *m) {
    *a = ipv4_network, *m = ipv4_network_mask;
  };
  inline bool are_ip_reassignment_alerts_enabled() {
    return (ip_reassignment_alerts_enabled);
  };
  inline void enable_ip_reassignment_alerts(bool status) {
    ip_reassignment_alerts_enabled = status;
  };
  inline AddressTree *getInterfaceNetworks() { return (&interface_networks); };
  virtual void startPacketPolling();
  virtual void startFlowDumping();
  virtual bool isLoading() { return false; };
  virtual void shutdown();
  virtual void cleanup();
  virtual char *getEndpoint(u_int8_t id) { return NULL; };
  virtual bool set_packet_filter(char *filter) { return (false); };
  virtual void incrDrops(u_int32_t num) { ; }
  /* calling virtual in constructors/destructors should be avoided
     See C++ FAQ Lite covers this in section 23.7
  */
  virtual bool isPacketInterface() const {
    return (getIfType() != interface_type_FLOW &&
            getIfType() != interface_type_ZMQ);
  }

  virtual bool isSyslogInterface() const {
    return (getIfType() == interface_type_SYSLOG);
  }
  void incSyslogStats(u_int32_t num_total_events, u_int32_t num_malformed,
                      u_int32_t num_dispatched, u_int32_t num_unhandled,
                      u_int32_t num_alerts, u_int32_t num_host_correlations,
                      u_int32_t num_collected_flows) {
    syslogStats.incStats(num_total_events, num_malformed, num_dispatched,
                         num_unhandled, num_alerts, num_host_correlations,
                         num_collected_flows);
  };

#if defined(__linux__) && !defined(HAVE_LIBCAP) && !defined(HAVE_NEDGE)
  /* Note: if we miss the capabilities, we block the overriding of this method.
   */
  inline bool
#else
  virtual bool
#endif
  isDiscoverableInterface() {
    return (false);
  }
  inline virtual const char *altDiscoverableName() { return (NULL); }
  virtual const char *get_type() const {
    return (customIftype ? customIftype : CONST_INTERFACE_TYPE_UNKNOWN);
  }
  virtual InterfaceType getIfType() const { return (interface_type_UNKNOWN); }
  inline FlowHash *get_flows_hash() { return flows_hash; }
  inline TcpFlowStats *getTcpFlowStats() { return (&tcpFlowStats); }
  virtual bool is_ndpi_enabled() const { return (true); }
  inline u_int getNumnDPIProtocols() {
    return (ndpi_get_num_supported_protocols(get_ndpi_struct()));
  };
  inline time_t getTimeLastPktRcvdRemote() { return (last_pkt_rcvd_remote); };
  inline time_t getTimeLastPktRcvd() {
    return (last_pkt_rcvd ? last_pkt_rcvd : last_pkt_rcvd_remote);
  };
  inline void setTimeLastPktRcvd(time_t t) {
    if (t > last_pkt_rcvd) last_pkt_rcvd = t;
  };
  inline const char *get_ndpi_category_name(ndpi_protocol_category_t category) {
    return (ndpi_category_get_name(get_ndpi_struct(), category));
  };
  inline char *get_ndpi_proto_name(u_int id) {
    return (ndpi_get_proto_name(get_ndpi_struct(), id));
  };
  inline u_int16_t get_ndpi_proto_id(char *proto) {
    u_int16_t _proto = ndpi_get_proto_by_name(get_ndpi_struct(), proto);
    return ndpi_map_ndpi_id_to_user_proto_id(get_ndpi_struct(), _proto);
  };
  inline int get_ndpi_category_id(char *cat) {
    return (ndpi_get_category_id(get_ndpi_struct(), cat));
  };
  inline char *get_ndpi_proto_breed_name(u_int id) {
    return (ndpi_get_proto_breed_name(ndpi_get_proto_breed(get_ndpi_struct(), id)));
  };
  inline char *get_ndpi_full_proto_name(ndpi_protocol protocol, char *buf,
                                        u_int buf_len) const {
    return (ndpi_protocol2name(get_ndpi_struct(), protocol, buf, buf_len));
  }
  inline u_int get_flow_size() {
    return (ndpi_detection_get_sizeof_ndpi_flow_struct());
  };
  inline char *get_name() const { return (ifname); };
  inline char *get_description() const { return (ifDescription); };
  inline int get_id() const { return (id); };
  inline bool get_inline_interface() { return inline_interface; }
  virtual bool hasSeenVLANTaggedPackets() const { return (has_vlan_packets); }
  inline void setSeenVLANTaggedPackets() { has_vlan_packets = true; }
  inline bool hasSeenEBPFEvents() const { return (has_ebpf_events); }
  inline void setSeenEBPFEvents() { has_ebpf_events = true; }
  inline bool hasSeenMacAddresses() const { return (has_mac_addresses); }
  inline void setSeenMacAddresses() { has_mac_addresses = true; }
  inline bool hasSeenDHCPAddresses() const { return (has_seen_dhcp_addresses); }
  inline void setDHCPAddressesSeen() { has_seen_dhcp_addresses = true; }
  inline bool hasSeenPods() const { return (has_seen_pods); }
  inline void setSeenPods() { has_seen_pods = true; }
  inline bool hasSeenContainers() const { return (has_seen_containers); }
  inline void setSeenContainers() { has_seen_containers = true; }
  inline bool hasSeenExternalAlerts() const { return (has_external_alerts); }
  inline void setSeenExternalAlerts() { has_external_alerts = true; }
  inline bool is_purge_idle_interface() { return (purge_idle_flows_hosts); };
  int dumpFlow(time_t when, Flow *f);
  bool getHostMinInfo(lua_State *vm, AddressTree *allowed_hosts, char *host_ip,
                      u_int16_t vlan_id, bool only_ndpi_stats);

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
  void checkPointHostTalker(lua_State *vm, char *host_ip, u_int16_t vlan_id);
  inline void incRetransmittedPkts(u_int32_t num) {
    tcpPacketStats.incRetr(num);
  };
  inline void incOOOPkts(u_int32_t num) { tcpPacketStats.incOOO(num); };
  inline void incLostPkts(u_int32_t num) { tcpPacketStats.incLost(num); };
  inline void incKeepAlivePkts(u_int32_t num) {
    tcpPacketStats.incKeepAlive(num);
  };

  virtual void checkPointCounters(bool drops_only);
  bool registerSubInterface(NetworkInterface *sub_iface, u_int64_t criteria);

  /* Overridden in ViewInterface.cpp */
  virtual u_int64_t getCheckPointNumPackets();
  virtual u_int64_t getCheckPointDroppedAlerts();
  virtual u_int64_t getCheckPointNumBytes();
  virtual u_int32_t getCheckPointNumPacketDrops();
  virtual u_int64_t getCheckPointNumTrafficSent() const;
  virtual u_int64_t getCheckPointNumTrafficRcvd() const;
  virtual u_int64_t getCheckPointNumPacketsSent() const;
  virtual u_int64_t getCheckPointNumPacketsRcvd() const;
  inline void incFlagStats(u_int8_t flags, bool cumulative_flags) {
    pktStats.incFlagStats(flags, cumulative_flags);
  };

  inline void incStats(bool ingressPacket, time_t when, u_int16_t eth_proto,
                       u_int16_t ndpi_proto,
                       ndpi_protocol_category_t ndpi_category, u_int8_t l4proto,
                       u_int32_t pkt_len, u_int32_t num_pkts) {
    /* NOTE: nEdge does the incs in NetfilterInterface::incStatsConntrack, keep
     * it in sync! */
#ifndef HAVE_NEDGE
    incEthStats(ingressPacket, eth_proto, num_pkts, pkt_len, getPacketOverhead());

    // incnDPIStats(when, ndpi_proto, ndpi_category, pkt_len, num_pkts);
    
    pktStats.incStats(1, pkt_len);
    l4Stats.incStats(when, l4proto, ingressPacket ? num_pkts : 0,
                     ingressPacket ? pkt_len : 0, !ingressPacket ? num_pkts : 0,
                     !ingressPacket ? pkt_len : 0);
#endif

#ifdef NTOPNG_PRO
    /* Added DHCP storm detection */
    if (ndpi_proto == NDPI_PROTOCOL_DHCP) checkDHCPStorm(when, num_pkts);
#endif
  };

  inline void incICMPStats(bool is_icmpv6, u_int32_t num_pkts,
                           u_int8_t icmp_type, u_int8_t icmp_code, bool sent) {
    if (is_icmpv6)
      icmp_v6.incStats(num_pkts, icmp_type, icmp_code, sent, NULL);
    else
      icmp_v4.incStats(num_pkts, icmp_type, icmp_code, sent, NULL);
  };

  inline void incLocalStats(u_int num_pkts, u_int pkt_len, bool localsender,
                            bool localreceiver) {
    localStats.incStats(num_pkts, pkt_len, localsender, localreceiver);
  };
  
  inline void incnDPIFlows(u_int16_t l7_protocol) {
    ndpiStats->incFlowsStats(l7_protocol);
  }

  inline void incDSCPStats(u_int8_t ds, u_int64_t sent_packets,
                           u_int64_t sent_bytes, u_int64_t rcvd_packets,
                           u_int64_t rcvd_bytes) {
    dscpStats->incStats(ds, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
  }

  virtual void sumStats(TcpFlowStats *_tcpFlowStats, EthStats *_ethStats,
                        LocalTrafficStats *_localStats, nDPIStats *_ndpiStats,
                        PacketStats *_pktStats, TcpPacketStats *_tcpPacketStats,
                        DSCPStats *_dscpStats, SyslogStats *_syslogStats,
                        RoundTripStats *_downloadStats,
                        RoundTripStats *_uploadStats) const;
  inline DB *getDB() const { return db; };
  inline EthStats* getStats() { return (&ethStats); };
  inline int get_datalink() { return (pcap_datalink_type); };
  inline void set_datalink(int l) { pcap_datalink_type = l; };
  bool isStartingUp() const;
  bool isRunning() const;
  bool isShuttingDown() const;
  inline bool isTrafficMirrored() const { return is_traffic_mirrored; };
  bool isSmartRecordingEnabled() const;
  inline const char *getSmartRecordingInstance() const { return smart_recording_instance_name; };
  inline bool showDynamicInterfaceTraffic() const {
    return show_dynamic_interface_traffic;
  };
  inline bool pushHostFilters() const { return push_host_filters; };
  inline bool flowsOnlyInterface() const { return flows_only_interface; };
  void updateTrafficMirrored();
  void updateSmartRecording();
  void updateDynIfaceTrafficPolicy();
  void updatePushFiltersSettings();
  void updateFlowDumpDisabled();
  void updateLbdIdentifier();
  void updateFlowsOnlyInterface();
  u_int printAvailableInterfaces(bool printHelp, int idx, char *ifname,
                                 u_int ifname_len);
  void findFlowHosts(int32_t _iface_idx, u_int16_t vlan_id,
		     u_int16_t observation_domain_id,
                     u_int32_t private_flow_id, Mac *src_mac,
                     IpAddress *_src_ip, Host **src, Mac *dst_mac,
                     IpAddress *_dst_ip, Host **dst);
  virtual Flow *findFlowByKeyAndHashId(u_int32_t key, u_int hash_id,
                                       AddressTree *allowed_hosts);
  virtual Flow *findFlowByTuple(u_int16_t vlan_id,
                                u_int16_t observation_domain_id,
                                u_int32_t private_flow_id, Mac *src_mac,
                                Mac *dst_mac, IpAddress *src_ip,
                                IpAddress *dst_ip, u_int16_t src_port,
                                u_int16_t dst_port, u_int8_t l4_proto,
                                AddressTree *allowed_hosts) const;
  bool findHostsByName(lua_State *vm, AddressTree *allowed_hosts, char *key);
  bool findHostsByMac(lua_State *vm, u_int8_t *mac);
  Host *findHostByMac(u_int8_t *mac);

  bool dissectPacket(int32_t iface_index, u_int32_t bridge_iface_idx,
		     int datalink_type, bool ingressPacket,
		     u_int8_t *sender_mac, /* Non NULL only for NFQUEUE interfaces */
		     const struct pcap_pkthdr *h, const u_char *packet,
		     u_int16_t *ndpiProtocol, Host **srcHost, Host **dstHost, Flow **flow);
  bool processPacket(int32_t if_index, u_int32_t bridge_iface_idx,
		     int datalink_type, bool *ingressPacket /* in/out */,
                     const struct bpf_timeval *when, const u_int64_t time,
                     struct ndpi_ethhdr *eth, u_int16_t vlan_id,
                     struct ndpi_iphdr *iph, struct ndpi_ipv6hdr *ip6,
                     u_int16_t ip_offset, u_int16_t encapsulation_overhead,
                     u_int32_t len_on_wire, const struct pcap_pkthdr *h,
                     const u_char *packet, u_int16_t *ndpiProtocol,
                     Host **srcHost, Host **dstHost, Flow **flow);
  void processInterfaceStats(sFlowInterfaceStats *stats);
  void getActiveFlowsStats(nDPIStats *stats, FlowStats *status_stats,
                           AddressTree *allowed_hosts, Host *h,
                           Host *talking_with_host, Host *client, Host *server,
                           char *flow_info, Paginator *p, lua_State *vm,
                           bool only_traffic_stats);
  virtual u_int32_t periodicStatsUpdateFrequency() const;
  void periodicStatsUpdate();
  u_int64_t purgeQueuedIdleEntries();
  struct timeval periodicUpdateInitTime() const;
  virtual u_int32_t getFlowMaxIdle();

  virtual void lua(lua_State *vm, bool fullStats);
  virtual void probeLuaStats(lua_State *vm) { };
  void luaScore(lua_State *vm);
  void luaAlertedFlows(lua_State *vm);
  void luaAnomalies(lua_State *vm);
  void luaNdpiStats(lua_State *vm, bool diff = false);
  void luaPeriodicityFilteringMenu(lua_State *vm, MapsFilters *filters);
  void luaServiceFilteringMenu(lua_State *vm, MapsFilters *filters);
  void luaPeriodicityMap(lua_State *vm, MapsFilters *filters);
  void luaServiceMap(lua_State *vm, MapsFilters *filters);
  void luaSubInterface(lua_State *vm);
  void luaServiceMapStatus(lua_State *vm);
  inline u_int8_t *getIfMac() { return ifMac; };
  inline float getThroughputBps() { return bytes_thpt.getThpt(); };
  inline float getThroughputPps() { return pkts_thpt.getThpt(); };
#if defined(NTOPNG_PRO)
  inline bool isServiceMapLearning() const {
    return (sMap ? sMap->isLearning() : false);
  }
  inline ServiceMap *getServiceMap() { return (sMap); };
  inline bool isServiceMapEnabled() { return (sMap ? true : false); };
  inline void flushServiceMap() {
    if (sMap) sMap->flush();
  };
  inline PeriodicityMap *getPeriodicityMap() { return (pMap); };
  inline bool isPeriodicityMapEnabled() { return (pMap ? true : false); };
  inline void flushPeriodicityMap() {
    if (pMap) pMap->flush();
  };
  void updateFlowPeriodicity(Flow *f);
  void updateServiceMap(Flow *f);

  /* Access Control List */
  inline bool insertIPACL(u_int8_t protocol, char *src, char *dst, char* port, u_int16_t l7_proto, bool is_allowed) {
    if (acl_flow) return acl_flow->insertIPACL(protocol, src, dst, port, l7_proto, is_allowed);
    return false;
  }
  inline bool removeIPACL(u_int8_t protocol, char *src, char *dst, char* port, u_int16_t l7_proto) {
    if (acl_flow) return acl_flow->removeIPACL(protocol, src, dst, port, l7_proto);
    return false;
  }
  inline bool insertMacACL(u_int8_t *mac, bool is_allowed) {
    if (acl_flow) return acl_flow->insertMacACL(mac, is_allowed);
    return false;
  }
  inline bool removeMacACL(u_int8_t *mac) {
    if (acl_flow) return acl_flow->removeMacACL(mac);
    return false;
  }
  inline bool findFlowACL(Flow *f, bool *is_allowed) {
    if (acl_flow) return acl_flow->findFlowACL(f, is_allowed);
    return false;
  }
  inline bool findMacACL(u_int8_t* mac, bool *is_allowed) {
    if (acl_flow) return acl_flow->findMacACL(mac, is_allowed);
    return false;
  }
  inline void getACLInfo(lua_State *vm) {
    if (acl_flow) acl_flow->lua(vm);
  }
#endif
  void lua_hash_tables_stats(lua_State *vm);
  void lua_periodic_activities_stats(lua_State *vm);
  virtual void lua_queues_stats(lua_State *vm);
  void getnDPIProtocols(lua_State *vm, ndpi_protocol_category_t filter,
                        bool skip_critical);

  int getActiveHostsList(
			 lua_State *vm, u_int32_t *begin_slot, bool walk_all,
			 u_int8_t bridge_iface_idx, AddressTree *allowed_hosts, bool host_details,
			 LocationPolicy location, char *countryFilter, char *mac_filter,
			 u_int16_t vlan_id, OSType osFilter, u_int32_t asnFilter,
			 int32_t networkFilter, u_int16_t pool_filter, bool filtered_hosts,
			 bool blacklisted_hosts, u_int8_t ipver_filter, int proto_filter,
			 TrafficType traffic_type_filter, u_int32_t device_ip, bool tsLua,
			 bool anomalousOnly, bool dhcpOnly, const AddressTree *const cidr_filter,
			 char *sortColumn, u_int32_t maxHits, u_int32_t toSkip, bool a2zSortOrder, bool useArrayFormat);
  int getActiveASList(lua_State *vm, const Paginator *p, bool diff = false);
  int getActiveObsPointsList(lua_State *vm, const Paginator *p);
  int getActiveCountriesList(lua_State *vm, const Paginator *p);
  int getActiveVLANList(lua_State *vm, char *sortColumn, u_int32_t maxHits,
                        u_int32_t toSkip, bool a2zSortOrder,
                        DetailsLevel details_level);
  int getActiveMacList(lua_State *vm, u_int32_t *begin_slot, bool walk_all,
                       u_int8_t bridge_iface_idx, bool sourceMacsOnly,
                       const char *manufacturer, char *sortColumn,
                       u_int32_t maxHits, u_int32_t toSkip, bool a2zSortOrder,
                       u_int16_t pool_filter, u_int8_t devtype_filter,
                       u_int8_t location_filter, time_t min_first_seen);
  int getActiveMacManufacturers(lua_State *vm, u_int8_t bridge_iface_idx,
                                bool sourceMacsOnly, u_int32_t maxHits,
                                u_int8_t devtype_filter,
                                u_int8_t location_filter);
  bool getActiveMacHosts(lua_State *vm, const char *mac);
  int getActiveDeviceTypes(lua_State *vm, u_int8_t bridge_iface_idx,
                           bool sourceMacsOnly, u_int32_t maxHits,
                           const char *manufacturer, u_int8_t location_filter);
  int getMacsIpAddresses(lua_State *vm, int idx);
  void getFlowsStats(lua_State *vm);
  void getNetworkStats(lua_State *vm, u_int32_t network_id,
                       AddressTree *allowed_hosts, bool diff = false) const;
  void getNetworksStats(lua_State *vm, AddressTree *allowed_hosts,
                        bool diff = false) const;
  int getFlows(lua_State *vm, u_int32_t *begin_slot, bool walk_all,
               AddressTree *allowed_hosts, Host *host, Host *talking_with_host,
               Host *client, Host *server, char *flow_info, Paginator *p);
  int getFlowsTraffic(lua_State *vm, u_int32_t *begin_slot, bool walk_all,
                      AddressTree *allowed_hosts, Host *host, Paginator *p);
  int getFlowsGroup(lua_State *vm, AddressTree *allowed_hosts, Paginator *p,
                    const char *groupColumn);
  int dropFlowsTraffic(AddressTree *allowed_hosts, Paginator *p);

  virtual void purgeIdle(time_t when, bool force_idle = false,
                         bool full_scan = false);
  u_int purgeIdleFlows(bool force_idle, bool full_scan);
  u_int purgeIdleHosts(bool force_idlei, bool full_scan);
  u_int purgeIdleMacsASesCountriesVLANs(bool force_idle, bool full_scan);

  /* Overridden in ViewInterface.cpp */
  virtual u_int64_t getNumPackets();
  virtual u_int64_t getNumBytes();
  virtual u_int64_t getNumDroppedAlerts();
  virtual void updatePacketsStats(){};
  virtual u_int32_t getNumDroppedPackets() { return 0; };
  virtual u_int getNumPacketDrops();
  virtual u_int64_t getNumNewFlows();
  virtual u_int getNumFlows();
  inline u_int getNumL2Devices() { return (numL2Devices); };
  inline u_int getNumHosts() { return (totalNumHosts); };
  inline u_int getNumLocalHosts() { return (numLocalHosts); };
  inline u_int getNumRxOnlyHosts() { return (numTotalRxOnlyHosts); };
  inline u_int getNumLocalRxOnlyHosts() { return (numLocalRxOnlyHosts); };

  u_int getNumMacs();
  u_int getNumHTTPHosts();

  inline u_int64_t getNumPacketsSinceReset() {
    return getNumPackets() - getCheckPointNumPackets();
  }
  inline u_int64_t getNumBytesSinceReset() {
    return getNumBytes() - getCheckPointNumBytes();
  }
  inline u_int64_t getNumPacketDropsSinceReset() {
    return getNumPacketDrops() - getCheckPointNumPacketDrops();
  }
  inline u_int64_t getNumDroppedAlertsSinceReset() {
    return getNumDroppedAlerts() - getCheckPointDroppedAlerts();
  }

  void runPeriodicHousekeepingTasks();
  void runShutdownTasks();
  VLAN *getVLAN(u_int16_t u_int16_t, bool create_if_not_present,
                bool is_inline_call);
  AutonomousSystem *getAS(IpAddress *ipa, bool create_if_not_present,
                          bool is_inline_call);
  ObservationPoint *getObsPoint(u_int16_t obs_point, bool create_if_not_present,
                                bool is_inline_call);
  bool deleteObsPoint(u_int16_t obs_point);
  bool prepareDeleteObsPoint(u_int16_t obs_point);
  Country *getCountry(const char *country_name, bool create_if_not_present,
                      bool is_inline_call);
  virtual Mac *getMac(u_int8_t _mac[6], bool create_if_not_present,
                      bool is_inline_call);
  virtual Host *getHost(char *host_ip, u_int16_t vlan_id,
                        u_int16_t observationPointId, bool is_inline_call);
  virtual Host *getHostByIP(IpAddress *ip, u_int16_t vlan_id,
                            u_int16_t observationPointId, bool is_inline_call);
  bool getHostInfo(lua_State *vm, AddressTree *allowed_hosts, char *host_ip,
                   u_int16_t vlan_id);
  void findPidFlows(lua_State *vm, u_int32_t pid);
  void findProcNameFlows(lua_State *vm, char *proc_name);
  void addAllAvailableInterfaces();
  inline bool idle() { return (is_idle); }
  inline u_int16_t getMTU() { return (ifMTU); }
  virtual u_int getPacketOverhead() {
    return 24 /* 8 Preamble + 4 CRC + 12 IFG */;
  }
  inline void setIdleState(bool new_state) { is_idle = new_state; };
  inline StatsManager *getStatsManager() { return statsManager; };
  AlertsQueue *getAlertsQueue() const;
  bool alert_store_query(lua_State *vm, const char *sql, bool limit_rows);

  void listHTTPHosts(lua_State *vm, char *key);
#ifdef NTOPNG_PRO
  void refreshL7Rules();
  void refreshShapers();
  inline L7Policer *getL7Policer() { return (policer); }
  inline FlowInterfacesStats *getFlowInterfacesStats() {
    return (flow_interfaces_stats);
  }
#endif
  inline HostPools *getHostPools() { return (host_pools); }
  inline void reloadHostPools() {
    if (host_pools) host_pools->reloadPools();
  }
  inline u_int16_t getNumberHostPools() {
    if (host_pools) 
      return host_pools->getCurrentHostPoolsNumber();
    return 0;
  }
  inline u_int32_t getNumberHostPoolsMembers() {
    if (host_pools) 
      return host_pools->getCurrentMaxHostPoolsMembers();
    return 0;
  }

  bool registerLiveCapture(NtopngLuaContext *const luactx, int *id);
  bool deregisterLiveCapture(NtopngLuaContext *const luactx);
  void dumpLiveCaptures(lua_State *vm);
  bool stopLiveCapture(int capture_id);
#ifdef NTOPNG_PRO
#ifdef HAVE_NEDGE
  void updateHostsL7Policy(u_int16_t host_pool_id);
  void updateFlowsL7Policy();
#endif
  void resetPoolsStats(u_int16_t pool_filter);
#endif
  inline void luaHostPoolsStats(lua_State *vm) {
    if (host_pools) host_pools->luaStats(vm);
  };
  void refreshHostPools();
  inline u_int16_t getHostPool(Host *h, bool *mac_match) {
    if (h && host_pools) return host_pools->getPool(h, mac_match);
    return NO_HOST_POOL_ID;
  };
  inline u_int16_t getHostPool(Mac *m) {
    if (m && host_pools) return host_pools->getPool(m);
    return NO_HOST_POOL_ID;
  };

  void loadScalingFactorPrefs();
  void getnDPIFlowsCount(lua_State *vm);

#ifdef HAVE_NEDGE
  inline void setInterfaceLocation(u_int32_t interface_id,
                                   InterfaceLocation location) {
    bridge_interface_id_to_location[interface_id] = location;
  }
  inline InterfaceLocation getInterfaceLocation(u_int32_t interface_id) {
    std::map<u_int32_t, InterfaceLocation>::iterator it;
    if ((it = bridge_interface_id_to_location.find(interface_id)) !=
        bridge_interface_id_to_location.end())
      return it->second;
    else
      return unknown_interface;
  }
#endif

  inline HostHash *get_hosts_hash() { return (hosts_hash); }
  inline bool is_bridge_interface() { return (bridge_interface); }
  inline const char *getLocalIPAddresses() { return (ip_addresses.c_str()); }
  void addInterfaceAddress(char *const addr);
  void addInterfaceNetwork(char *const net, char *addr);
  bool isInterfaceNetwork(IpAddress *ipa, int network_bits);
  inline int select_database(char *dbname) {
    return (db ? db->select_database(dbname) : -1);
  };
  inline int exec_sql_query(lua_State *vm, char *sql, bool limit_rows,
                            bool wait_for_db_created = false) {
    return (db ? db->exec_sql_query(vm, sql, limit_rows, wait_for_db_created)
	    : -1);
  };
  int exec_csv_query(const char *sql, bool dump_in_json_format,
                     struct mg_connection *conn);

  NetworkStats *getNetworkStats(u_int32_t networkId) const;
  void allocateStructures(bool disable_dump = false);
  void getsDPIStats(lua_State *vm);
  inline bool isDbCreated() { return (db ? db->isDbCreated() : true); };
#ifdef NTOPNG_PRO
  void updateFlowProfiles();
#ifndef HAVE_NEDGE
  inline FlowProfile *getFlowProfile(Flow *f) {
    return (flow_profiles ? flow_profiles->getFlowProfile(f) : NULL);
  }
  inline bool checkFilterSyntax(char *filter) {
    return (flow_profiles ? flow_profiles->checkFilterSyntax(filter) : false);
  }

  inline bool checkSubInterfaceSyntax(char *filter) {
    return (sub_interfaces ? sub_interfaces->checkSyntax(filter) : false);
  }
#endif

  bool passShaperPacket(TrafficShaper *a_shaper, TrafficShaper *b_shaper,
                        struct pcap_pkthdr *h);
  void initL7Policer();
#endif

  void getFlowsStatus(lua_State *vm);
  inline void startDBLoop() {
    if (db) db->startDBLoop();
  };
  inline void incDBNumDroppedFlows(DB *dumper, u_int num = 1) {
    if (dumper) dumper->incNumDroppedFlows(num);
  };
#ifdef NTOPNG_PRO
  void updateBehaviorStats(const struct timeval *tv);

  virtual void getFlowDevices(lua_State *vm);
  virtual void getFlowDeviceInfo(lua_State *vm, u_int32_t deviceID, bool showAllStats = true) {
    if (flow_interfaces_stats) {
      lua_newtable(vm);
      flow_interfaces_stats->luaDeviceInfo(vm, deviceID, this, showAllStats);
      lua_pushinteger(vm, get_id());
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  };  
  virtual void getFlowDeviceInfoByIP(lua_State *vm, u_int32_t deviceIP, bool showAllStats = true) {
    if (flow_interfaces_stats) {
      lua_newtable(vm);
      flow_interfaces_stats->luaDeviceInfoByIP(vm, deviceIP, this, showAllStats);
      lua_pushinteger(vm, get_id());
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  };
#endif
  virtual void getSFlowDevices(lua_State *vm, bool add_table);
  virtual void getSFlowDeviceInfo(lua_State *vm, u_int32_t deviceID) {
    if (interfaceStats)
      interfaceStats->luaDeviceInfo(vm, deviceID);
    else
      lua_newtable(vm);
  };
  int updateHostTrafficPolicy(AddressTree *allowed_networks, char *host_ip,
                              u_int16_t host_vlan);

  virtual void reloadCompanions(){};

  void requestGwMacsReload() { gw_macs_reload_requested = true; };
  void reloadGwMacs();

  inline bool serializeLbdHostsAsMacs() { return (lbd_serialize_by_mac); }
  void checkReloadHostsBroadcastDomain();
  inline bool reloadHostsBroadcastDomain() { return reload_hosts_bcast_domain; }
  void reloadHostsBlacklist();
  void checkNetworksAlerts(vector<ScriptPeriodicity> *p, lua_State *vm);
  void checkInterfaceAlerts(vector<ScriptPeriodicity> *p, lua_State *vm);
  virtual bool areTrafficDirectionsSupported() { return (true); };

  inline bool isView() const { return is_view; };
  inline ViewInterface *viewedBy() const { return viewed_by; };
  inline u_int8_t getViewedId() const { return viewed_interface_id; };
  inline bool isViewed() const { return viewedBy() != NULL; };
  /*
    Method called by a view interface on all its viewed interfaces.
    The view passes to this method both its pointer and the viewed interface id,
    that is, a numeric identifier for the viewed interface inside the view
    interface.
  */
  inline void setViewed(ViewInterface *view_iface,
                        u_int8_t _viewed_interface_id) {
    viewed_by = view_iface;
    viewed_interface_id = _viewed_interface_id;
  };

  bool getMacInfo(lua_State *vm, char *mac);
  bool resetMacStats(lua_State *vm, char *mac, bool delete_data);
  bool setMacDeviceType(char *strmac, DeviceType dtype, bool alwaysOverwrite);
  bool getASInfo(lua_State *vm, u_int32_t asn);
  bool getObsPointInfo(lua_State *vm, u_int16_t obs_point);
  bool getCountryInfo(lua_State *vm, const char *country);
  bool getVLANInfo(lua_State *vm, u_int16_t vlan_id);
  void incNumHosts(Host *host, bool rxOnlyHost);
  void decNumHosts(Host *host, bool rxOnlyHost);
  inline void incNumL2Devices() { numL2Devices++; }
  inline void decNumL2Devices() { numL2Devices--; }
  inline u_int32_t getScalingFactor() const { return (scalingFactor); }
  inline void setScalingFactor(u_int32_t f) { scalingFactor = f; }
  virtual bool isSampledTraffic() const {
    return ((scalingFactor == 1) ? false : true);
  }
#ifdef NTOPNG_PRO
  virtual bool getCustomAppDetails(u_int32_t remapped_app_id,
                                   u_int32_t *const pen,
                                   u_int32_t *const app_field,
                                   u_int32_t *const app_id) {
    return false;
  };
  virtual void addToNotifiedInformativeCaptivePortal(u_int32_t client_ip) { ; };
  virtual void addIPToLRUMatches(u_int32_t client_ip, u_int16_t user_pool_id,
                                 char *label) {
    ;
  };
#endif

  inline void mdnsSendAnyQuery(char *targetIPv4, char *query) {
    if (mdns) mdns->sendAnyQuery(targetIPv4, query);
  }

  inline bool mdnsQueueResolveIPv4(u_int32_t ipv4addr, bool alsoUseGatewayDNS) {
    return (mdns ? mdns->queueResolveIPv4(ipv4addr, alsoUseGatewayDNS) : false);
  }

  inline void mdnsFetchResolveResponses(lua_State *vm,
                                        int32_t timeout_sec = 2) {
    if (mdns) mdns->fetchResolveResponses(vm, timeout_sec);
  }

  inline bool isSubInterface() { return (is_dynamic_interface); };
  void setSubInterface(NetworkInterface *master_iface, FlowHashingEnum mode,
                       u_int64_t criteria);
  NetworkInterface *getMasterInterface() { return dynamic_interface_master; };

  bool isLocalBroadcastDomainHost(Host *const h, bool is_inline_call);
  inline MDNS *getMDNS() { return (mdns); }
  inline NetworkDiscovery *getNetworkDiscovery() { return (discovery); }
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
  Host *findHostByIP(AddressTree *allowed_hosts, char *host_ip,
                     u_int16_t vlan_id, u_int16_t observationPointId);
  TimeseriesExporter *getInfluxDBTSExporter();
  TimeseriesExporter *getRRDTSExporter();

  inline uint32_t getMaxSpeed() const { return (ifSpeed); }
  inline bool isLoopback() const { return (is_loopback); }
  inline bool isGwMacConfigured() const {
    return (gw_macs->getNumEntries() > 0);
  }
  inline bool isGwMac(u_int8_t a[6]) const {
    return (isGwMacConfigured() && gw_macs->get(a, false) != NULL);
  }
  inline bool isInterfaceMac(u_int8_t a[6]) const {
    return (memcmp(a, ifMac, sizeof(ifMac)) == 0);
  }

  virtual bool read_from_stdin() const { return (false); };
  virtual bool read_from_pcap_dump() const { return (false); };
  virtual bool read_from_pcap_dump_done() const { return (false); };
  virtual void set_read_from_pcap_dump_done() { ; };
  /*
    Issue a request for user scripts reload. This is called by ntopng when user
    scripts should be reloaded, e.g., after a configuration change.
  */
  virtual void updateDirectionStats() { ; }
  void reloadDhcpRanges();

  /* Used to give the interface a new check loader to be used */
  void reloadFlowChecks(FlowChecksLoader *fcbl);
  void reloadHostChecks(HostChecksLoader *hcbl);

  inline bool hasConfiguredDhcpRanges() {
    return (dhcp_ranges && !dhcp_ranges->last_ip.isEmpty());
  };
  inline bool isFlowDumpDisabled() { return (flow_dump_disabled_by_user || 
    flow_dump_disabled_by_backend); }
  bool isInDhcpRange(IpAddress *ip);
  void getPodsStats(lua_State *vm);
  void getContainersStats(lua_State *vm, const char *pod_filter);
  bool enqueueFlowToCompanion(ParsedFlow *const pf, bool skip_loopback_traffic);
  bool dequeueFlowFromCompanion(ParsedFlow **pf);

#ifdef INTERFACE_PROFILING
  inline void profiling_section_enter(const char *label, int id) {
    INTERFACE_PROFILING_SECTION_ENTER(label, id);
  };
  inline void profiling_section_exit(int id) {
    INTERFACE_PROFILING_SECTION_EXIT(id);
  };
#endif

  void incNumActiveProbes();
  void decNumActiveProbes();
  u_int64_t getNumActiveProbes() const;

  void incNumAlertedFlows(Flow *f, AlertLevel severity);
  void decNumAlertedFlows(Flow *f, AlertLevel severity);
  virtual u_int64_t getNumActiveAlertedFlows() const;
  virtual u_int64_t getNumActiveAlertedFlows(
					     AlertLevelGroup alert_level_group) const;
  void incNumAlertsEngaged(AlertEntity alert_entity, AlertLevel alert_severity);
  void decNumAlertsEngaged(AlertEntity alert_entity, AlertLevel alert_severity);
  void incNumDroppedAlerts(AlertEntity alert_entity);
  inline void incNumWrittenAlerts() { num_written_alerts++; }
  inline void incNumAlertsQueries() { num_alerts_queries++; }
  inline u_int64_t getNumWrittenAlerts() { return (num_written_alerts); }
  inline u_int64_t getNumAlertsQueries() { return (num_alerts_queries); }
  void walkAlertables(AlertEntity alert_entity, const char *entity_value,
                      AddressTree *allowed_nets, alertable_callback *callback,
                      void *user_data);
  void getEngagedAlerts(lua_State *vm, AlertEntity alert_entity,
                        const char *entity_value, AlertType alert_type,
                        AlertLevel alert_severity, AlertRole role_filter,
                        AddressTree *allowed_nets);

  void processExternalAlertable(AlertEntity entity, const char *entity_val,
                                lua_State *vm, u_int vm_argument_idx,
                                bool do_store_alert);
  virtual bool reproducePcapOriginalSpeed() const { return (false); }
  u_int32_t getNumEngagedAlerts() const;
  u_int32_t getNumEngagedAlerts(AlertLevelGroup alert_level_group) const;
  void luaNumEngagedAlerts(lua_State *vm) const;
  int walkActiveHosts(lua_State *vm, HostWalkMode mode, u_int32_t maxHits,
                      int32_t networkIdFilter, bool localHostsOnly,
                      bool treeMapMode);
  virtual void
  flowAlertsDequeueLoop(); /* Body of the loop that dequeues flows for the
                              execution of user script hooks */
  virtual void hostAlertsDequeueLoop(); /* Same as above but for hosts */

  virtual void dumpFlowLoop(); /* Body of the loop that dequeues flows for the
                                  database dump */
  void incNumQueueDroppedFlows(u_int32_t num);
  /*
    Dequeues enqueued flows to dump them to database
  */
  u_int64_t dequeueFlowsForDump(u_int idle_flows_budget,
                                u_int active_flows_budget);

  void execProtocolDetectedChecks(Flow *f);
  void execPeriodicUpdateChecks(Flow *f);
  void execFlowEndChecks(Flow *f);
  void execFlowBeginChecks(Flow *f);
  void execHostChecks(Host *h);

  inline void incHostAnomalies(u_int32_t local, u_int32_t remote) {
    tot_num_anomalies.local_hosts += local,
      tot_num_anomalies.remote_hosts += remote;
  };

  /*
    Dequeues enqueued flows to execute user script checks.
    Budgets indicate how many flows should be dequeued (if available) to perform
    protocol detected, active, and idle checks.
  */
  u_int64_t dequeueFlowAlertsFromChecks(u_int budget);
  inline FlowChecksExecutor *getFlowCheckExecutor() {
    return (flow_checks_executor);
  }

  /* Same as above but for hosts */
  u_int64_t dequeueHostAlertsFromChecks(u_int budget);
  inline HostChecksExecutor *getHostCheckExecutor() {
    return (host_checks_executor);
  }
  HostCheck *getCheck(HostCheckID t);

  void incObservationPointIdFlows(u_int16_t pointId);

  bool hasObservationPointId(u_int16_t pointId);
  bool haveObservationPointsDefined();
  u_int16_t getFirstObservationPointId();

  struct ndpi_detection_module_struct *initnDPIStruct();
  bool initnDPIReload();
  void finalizenDPIReload();
  void cleanShadownDPI();
  inline bool isnDPIReloadInProgress() { return (ndpiReloadInProgress); }
  inline struct ndpi_detection_module_struct *get_ndpi_struct() const {
    return (ndpi_struct);
  };
  inline ndpi_protocol_category_t get_ndpi_proto_category(ndpi_protocol proto) {
    return (ndpi_get_proto_category(get_ndpi_struct(), proto));
  };
  ndpi_protocol_category_t get_ndpi_proto_category(u_int16_t protoid);
  void setnDPIProtocolCategory(struct ndpi_detection_module_struct *ndpi_str,
			       u_int16_t protoId,
                               ndpi_protocol_category_t protoCategory);
  bool nDPILoadIPCategory(char *what, u_int16_t id, char *list_name);
  bool nDPILoadHostnameCategory(char *what, u_int16_t id, char *list_name);
  int setDomainMask(const char *domain, u_int64_t domain_mask);
  int addTrustedIssuerDN(const char *dn);
  inline void setLastInterfacenDPIReload(time_t now) { last_ndpi_reload = now; }
  inline bool needsnDPICleanup() { return (ndpi_cleanup_needed); }
  inline void setnDPICleanupNeeded(bool needed) {
    ndpi_cleanup_needed = needed;
  }
  u_int16_t getnDPIProtoByName(const char *name);
  inline u_int32_t getNewFlowSerial() { return (flow_serial++); }
  inline u_int64_t getNewAlertSerial() { return alert_serial.fetch_add(1, std::memory_order_relaxed); }
  bool resetHostTopSites(AddressTree *allowed_hosts, char *host_ip,
                         u_int16_t vlan_id, u_int16_t observationPointId);
  void localHostsServerPorts(lua_State *vm);

  inline void setCustomFlowLuaScriptProtoDetected(LuaEngine *vm) {
    customFlowLuaScript_proto = vm;
  }
  inline void setCustomFlowLuaScriptPeriodic(LuaEngine *vm) {
    customFlowLuaScript_periodic = vm;
  }
  inline void setCustomFlowLuaScriptEnd(LuaEngine *vm) {
    customFlowLuaScript_end = vm;
  }
  inline LuaEngine *getCustomFlowLuaScriptProtoDetected() {
    return (customFlowLuaScript_proto);
  }
  inline LuaEngine *getCustomFlowLuaScriptPeriodic() {
    return (customFlowLuaScript_periodic);
  }
  inline LuaEngine *getCustomFlowLuaScriptEnd() {
    return (customFlowLuaScript_end);
  }

  inline void setCustomHostLuaScript(LuaEngine *vm) {
    customHostLuaScript = vm;
  }
  inline LuaEngine *getCustomHostLuaScript() { return (customHostLuaScript); }

  inline void setServerPort(bool isTCP, u_int16_t port, ndpi_protocol *proto) {
    usedPorts.setServerPort(isTCP, port, proto);
  };
  void luaUsedPorts(lua_State *vm) { usedPorts.lua(vm, this); };

  void getHostsPorts(lua_State *vm);
  void getHostsByPort(lua_State *vm);
  void getHostsByService(lua_State *vm);
  void getFilteredLiveFlowsStats(lua_State *vm);
  void getVLANFlowsStats(lua_State *vm);
  void getRxOnlyHostsList(lua_State *vm, bool local_host_rx_only,
                          bool list_host_peers);

  static bool compute_protocol_flow_stats(GenericHashEntry *node,
					  void *user_data, bool *matched);
  static bool compute_client_flow_stats(GenericHashEntry *node, void *user_data,
					bool *matched);
  static bool compute_server_flow_stats(GenericHashEntry *node, void *user_data,
					bool *matched);
  static bool compute_client_server_srv_port_flow_stats(GenericHashEntry *node,
          void *user_data,
          bool *matched);
  static bool compute_client_server_srv_port_app_proto_flow_stats(GenericHashEntry *node,
          void *user_data,
          bool *matched);
  static bool get_host_ports(GenericHashEntry *node,
				 void *user_data,
				 bool *matched);
  static bool get_hosts_by_port(GenericHashEntry *node,
				void *user_data,
				bool *matched);
  static bool get_hosts_by_service(GenericHashEntry *node,
				   void *user_data,
				   bool *matched);

#ifdef NTOPNG_PRO
  static bool compute_client_server_flow_stats(GenericHashEntry *node,
                                               void *user_data, bool *matched);
  static bool compute_app_client_server_flow_stats(GenericHashEntry *node,
                                                   void *user_data,
                                                   bool *matched);
  static bool compute_info_flow_stats(GenericHashEntry *node, void *user_data,
                                      bool *matched);

#ifndef HAVE_NEDGE
  inline u_int8_t getNumProfiles() { return (flow_profiles) ? flow_profiles->getNumProfiles() : 0; }
#endif
#endif
  void getActiveMacs(lua_State *vm);

  void incnDPIStats(time_t when, u_int16_t ndpi_proto,
		    ndpi_protocol_category_t ndpi_category,
		    u_int32_t bytes_sent, u_int32_t bytes_rcvd, 
        u_int32_t pkts_sent, u_int32_t pkts_rcvd);
};

#endif /* _NETWORK_INTERFACE_H_ */
