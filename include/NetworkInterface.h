/*
 *
 * (C) 2013-18 - ntop.org
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
class Vlan;
class VlanHash;
class AutonomousSystem;
class AutonomousSystemHash;
class Country;
class CountriesHash;
class DB;
class Paginator;

#ifdef NTOPNG_PRO
class AggregatedFlow;
class AggregatedFlowHash;
class L7Policer;
class FlowInterfacesStats;
class TrafficShaper;
class NIndexFlowDB;
#endif

typedef struct {
  u_int32_t criteria;        /* IP address, interface... */
  NetworkInterface *iface;
  UT_hash_handle hh;         /* makes this structure hashable */
} FlowHashing;

/** @class NetworkInterface
 *  @brief Main class of network interface of ntopng.
 *  @details .......
 *
 *  @ingroup NetworkInterface
 *
 */
class NetworkInterface : public Checkpointable {
 protected:
  char *ifname, *ifDescription;
  bpf_u_int32 ipv4_network_mask, ipv4_network;
  const char *customIftype;
  u_int8_t alertLevel, purgeRuns;
  u_int32_t bridge_lan_interface_id, bridge_wan_interface_id;
  u_int32_t num_hashes;

  /* Disaggregations */
  u_int16_t numVirtualInterfaces;
  set<u_int32_t>  flowHashingIgnoredInterfaces;
  FlowHashingEnum flowHashingMode;
  FlowHashing *flowHashing;

  /* Network Discovery */
  NetworkDiscovery *discovery;
  MDNS *mdns;

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
  int id;
  bool bridge_interface, is_dynamic_interface;
  bool reload_custom_categories;
#ifdef NTOPNG_PRO
  L7Policer *policer;
#ifndef HAVE_NEDGE
  FlowProfiles  *flow_profiles, *shadow_flow_profiles;
#endif
  FlowInterfacesStats *flow_interfaces_stats;
  AggregatedFlowHash *aggregated_flows_hash; /**< Hash used to store aggregated flows information. */
#endif
  EthStats ethStats;
  std::map<u_int32_t, u_int64_t> ip_mac; /* IP (network byte order) <-> MAC association [2 bytes are unused] */
  u_int32_t arp_requests, arp_replies;
  ICMPstats icmp_v4, icmp_v6;
  LocalTrafficStats localStats;
  int pcap_datalink_type; /**< Datalink type of pcap. */
  pthread_t pollLoop;
  bool pollLoopCreated, has_too_many_hosts, has_too_many_flows, mtuWarningShown, too_many_drops;
  u_int32_t ifSpeed, numL2Devices, numHosts, numLocalHosts, scalingFactor;
  u_int64_t checkpointPktCount, checkpointBytesCount, checkpointPktDropCount; /* Those will hold counters at checkpoints */
  u_int16_t ifMTU;
  int cpu_affinity; /**< Index of physical core where the network interface works. */
  nDPIStats ndpiStats;
  PacketStats pktStats;
  FlowHash *flows_hash; /**< Hash used to store flows information. */
  u_int32_t last_remote_pps, last_remote_bps;
  u_int8_t packet_drops_alert_perc;
  TimeSeriesExporter *tsExporter;

  /* Sub-interface views */
  u_int8_t numSubInterfaces;
  NetworkInterface *subInterfaces[MAX_NUM_VIEW_INTERFACES];

  u_int nextFlowAggregation;
  TcpFlowStats tcpFlowStats;
  TcpPacketStats tcpPacketStats;

  /* Frequent Items */
  FrequentTrafficItems *frequentProtocols;
  FrequentTrafficItems *frequentMacs;
  struct timeval last_frequent_reset;

  /* Mac */
  MacHash *macs_hash; /**< Hash used to store MAC information. */

  /* Autonomous Systems */
  AutonomousSystemHash *ases_hash; /**< Hash used to store Autonomous Systems information. */

  /* Countries */
  CountriesHash *countries_hash;

  /* Vlans */
  VlanHash *vlans_hash; /**< Hash used to store Vlans information. */

  /* Hosts */
  HostHash *hosts_hash; /**< Hash used to store hosts information. */
  bool purge_idle_flows_hosts, sprobe_interface, inline_interface,
    dump_all_traffic, dump_to_tap, dump_to_disk, dump_unknown_traffic;
  DB *db;
  u_int dump_sampling_rate, dump_max_pkts_file, dump_max_duration, dump_max_files;
  StatsManager  *statsManager;
  AlertsManager *alertsManager;
  HostPools *host_pools;
  VlanAddressTree *hide_from_top, *hide_from_top_shadow;
  bool has_vlan_packets, has_mac_addresses;
  struct ndpi_detection_module_struct *ndpi_struct;
  time_t last_pkt_rcvd, last_pkt_rcvd_remote, /* Meaningful only for ZMQ interfaces */
    next_idle_flow_purge, next_idle_host_purge;
  bool running, is_idle;
  PacketDumper *pkt_dumper;
  PacketDumperTuntap *pkt_dumper_tap;
  NetworkStats *networkStats;
  InterfaceStatsHash *interfaceStats;
  char checkpoint_compression_buffer[CONST_MAX_NUM_CHECKPOINTS][MAX_CHECKPOINT_COMPRESSION_BUFFER_SIZE];

  void init();
  void deleteDataStructures();
  NetworkInterface* getSubInterface(u_int32_t criteria, bool parser_interface);
  Flow* getFlow(Mac *srcMac, Mac *dstMac, u_int16_t vlan_id,
		u_int32_t deviceIP, u_int16_t inIndex, u_int16_t outIndex,
  		IpAddress *src_ip, IpAddress *dst_ip,
  		u_int16_t src_port, u_int16_t dst_port,
		u_int8_t l4_proto,
		bool *src2dst_direction,
		time_t first_seen, time_t last_seen,
		u_int32_t rawsize,
		bool *new_flow);
  int sortHosts(u_int32_t *begin_slot,
		bool walk_all,
		struct flowHostRetriever *retriever,
		u_int8_t bridge_iface_idx,
		AddressTree *allowed_hosts,
		bool host_details,
		LocationPolicy location,
		char *countryFilter, char *mac_filter,
		u_int16_t vlan_id, char *osFilter,
		u_int32_t asnFilter, int16_t networkFilter,
		u_int16_t pool_filter, bool filtered_hosts,
    bool blacklisted_hosts, bool hide_top_hidden,
    u_int8_t ipver_filter, int proto_filter,
		char *sortColumn);
  int sortASes(struct flowHostRetriever *retriever,
	       char *sortColumn);
  int sortCountries(struct flowHostRetriever *retriever,
	       char *sortColumn);
  int sortVLANs(struct flowHostRetriever *retriever,
		char *sortColumn);
  int sortMacs(u_int32_t *begin_slot,
	       bool walk_all,
	       struct flowHostRetriever *retriever,
	       u_int8_t bridge_iface_idx,
	       bool sourceMacsOnly,	bool dhcpMacsOnly,
	       const char *manufacturer,
	       char *sortColumn, u_int16_t pool_filter, u_int8_t devtype_filter,
	       u_int8_t location_filter);
  int sortFlows(u_int32_t *begin_slot,
		bool walk_all,
		struct flowHostRetriever *retriever,
		AddressTree *allowed_hosts,
		Host *host,
		Paginator *p,
		const char *sortColumn);

  bool isNumber(const char *str);
  bool validInterface(char *name);
  bool isInterfaceUp(char *name);
  bool checkIdle();
  void dumpPacketDisk(const struct pcap_pkthdr *h, const u_char *packet, dump_reason reason);
  void dumpPacketTap(const struct pcap_pkthdr *h, const u_char *packet, dump_reason reason);

  void disablePurge(bool on_flows);
  void enablePurge(bool on_flows);
  void sumStats(TcpFlowStats *_tcpFlowStats, EthStats *_ethStats,
		LocalTrafficStats *_localStats, nDPIStats *_ndpiStats,
		PacketStats *_pktStats, TcpPacketStats *_tcpPacketStats);

  void topItemsCommit(const struct timeval *when);
  void checkMacIPAssociation(bool triggerEvent, u_char *_mac, u_int32_t ipv4);

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

  void finishInitialization();
  virtual u_int32_t getASesHashSize();
  virtual u_int32_t getCountriesHashSize();
  virtual u_int32_t getVLANsHashSize();
  virtual u_int32_t getMacsHashSize();
  virtual u_int32_t getHostsHashSize();
  virtual u_int32_t getFlowsHashSize();

  virtual bool walker(u_int32_t *begin_slot,
		      bool walk_all,
		      WalkerType wtype,
		      bool (*walker)(GenericHashEntry *h, void *user_data, bool *entryMatched),
		      void *user_data);

  void checkAggregationMode();
  inline void setCPUAffinity(int core_id)      { cpu_affinity = core_id; };
  inline void getIPv4Address(bpf_u_int32 *a, bpf_u_int32 *m) { *a = ipv4_network, *m = ipv4_network_mask; };
  virtual void startPacketPolling();
  virtual void shutdown();
  virtual void cleanup();
  virtual char *getEndpoint(u_int8_t id)       { return NULL;   };
  virtual bool set_packet_filter(char *filter) { return(false); };
  virtual void incrDrops(u_int32_t num)        { ; }
  /* calling virtual in constructors/destructors should be avoided
     See C++ FAQ Lite covers this in section 23.7
  */
  inline virtual bool isPacketInterface()      { return(getIfType() != interface_type_FLOW); }
#if defined(linux) && !defined(HAVE_LIBCAP) && !defined(HAVE_NEDGE)
  /* Note: if we miss the capabilities, we block the overriding of this method. */
  inline bool isDiscoverableInterface()        { return(false);                              }
#else
  inline virtual bool isDiscoverableInterface(){ return(false);                              }
#endif
  inline virtual char* altDiscoverableName()   { return(NULL);                               }
  inline virtual const char* get_type()        { return(customIftype ? customIftype : CONST_INTERFACE_TYPE_UNKNOWN); }
  inline virtual InterfaceType getIfType()     { return(interface_type_UNKNOWN); }
  inline FlowHash *get_flows_hash()            { return flows_hash;     }
  inline TcpFlowStats* getTcpFlowStats()       { return(&tcpFlowStats); }
  inline virtual bool is_ndpi_enabled()        { return(true);          }
  inline u_int  getNumnDPIProtocols()          { return(ndpi_get_num_supported_protocols(ndpi_struct)); };
  inline time_t getTimeLastPktRcvd()           { return(last_pkt_rcvd ? last_pkt_rcvd : last_pkt_rcvd_remote); };
  inline void  setTimeLastPktRcvd(time_t t)    { last_pkt_rcvd = t; };
  inline ndpi_protocol_category_t get_ndpi_proto_category(ndpi_protocol proto) { return(ndpi_get_proto_category(ndpi_struct, proto)); };
  inline const char* get_ndpi_category_name(ndpi_protocol_category_t category) { return(ndpi_category_get_name(ndpi_struct, category)); };
  ndpi_protocol_category_t get_ndpi_proto_category(u_int protoid);
  inline char* get_ndpi_proto_name(u_int id)   { return(ndpi_get_proto_name(ndpi_struct, id));   };
  inline int   get_ndpi_proto_id(char *proto)  { return(ndpi_get_protocol_id(ndpi_struct, proto));   };
  inline int   get_ndpi_category_id(char *cat) { return(ndpi_get_category_id(ndpi_struct, cat));     };
  inline char* get_ndpi_proto_breed_name(u_int id) {
    return(ndpi_get_proto_breed_name(ndpi_struct, ndpi_get_proto_breed(ndpi_struct, id))); };
  inline u_int get_flow_size()                 { return(ndpi_detection_get_sizeof_ndpi_flow_struct()); };
  inline u_int get_size_id()                   { return(ndpi_detection_get_sizeof_ndpi_id_struct());   };
  inline char* get_name()                      { return(ifname);                                       };
  inline char* get_description()               { return(ifDescription);                                };
  inline int  get_id()                         { return(id);                                           };
  inline bool get_sprobe_interface()           { return sprobe_interface;  }
  inline bool get_inline_interface()           { return inline_interface;  }
  inline bool hasSeenVlanTaggedPackets()       { return(has_vlan_packets); }
  inline void setSeenVlanTaggedPackets()       { has_vlan_packets = true;  }
  inline bool hasSeenMacAddresses()            { return(has_mac_addresses); }
  inline void setSeenMacAddresses()            { has_mac_addresses = true;  }
  inline struct ndpi_detection_module_struct* get_ndpi_struct() { return(ndpi_struct);         };
  inline bool is_sprobe_interface()            { return(sprobe_interface);                     };
  inline bool is_purge_idle_interface()        { return(purge_idle_flows_hosts);               };
  inline void enable_sprobe()                  { sprobe_interface = true; };
  int dumpFlow(time_t when, Flow *f);
#ifdef NTOPNG_PRO
  int  dumpAggregatedFlow(AggregatedFlow *f);
  void flushFlowDump();
#endif
  int dumpDBFlow(time_t when, Flow *f);
  int dumpEsFlow(time_t when, Flow *f);
  int dumpLsFlow(time_t when, Flow *f);
#if defined(HAVE_NINDEX) && defined(NTOPNG_PRO)
  inline bool dumpnIndexFlow(time_t when, Flow *f)  { return(db->dumpFlow(when, f, NULL)); };
#endif
  int dumpLocalHosts2redis(bool disable_purge);
  inline void incRetransmittedPkts(u_int32_t num)   { tcpPacketStats.incRetr(num); };
  inline void incOOOPkts(u_int32_t num)             { tcpPacketStats.incOOO(num);  };
  inline void incLostPkts(u_int32_t num)            { tcpPacketStats.incLost(num); };
  bool checkPointHostCounters(lua_State* vm, u_int8_t checkpoint_id, char *host_ip, u_int16_t vlan_id, DetailsLevel details_level);
  bool checkPointNetworkCounters(lua_State* vm, u_int8_t checkpoint_id, u_int8_t network_id, DetailsLevel details_level);
  bool checkPointHostTalker(lua_State* vm, char *host_ip, u_int16_t vlan_id, bool saveCheckpoint);
  inline bool checkPointInterfaceCounters(lua_State* vm, u_int8_t checkpoint_id, DetailsLevel details_level) { return checkpoint(vm, this, checkpoint_id, details_level); }
  inline char* getCheckpointCompressionBuffer(u_int8_t checkpoint_id) { return (checkpoint_id<CONST_MAX_NUM_CHECKPOINTS) ? checkpoint_compression_buffer[checkpoint_id] : NULL; };
  void checkPointCounters(bool drops_only);
  bool serializeCheckpoint(json_object *my_object, DetailsLevel details_level);

  virtual u_int64_t getCheckPointNumPackets();
  virtual u_int64_t getCheckPointNumBytes();
  virtual u_int32_t getCheckPointNumPacketDrops();

  inline void _incStats(bool ingressPacket, time_t when,
			u_int16_t eth_proto, u_int16_t ndpi_proto,
		       u_int pkt_len, u_int num_pkts, u_int pkt_overhead) {
    ethStats.incStats(ingressPacket, eth_proto, num_pkts, pkt_len, pkt_overhead);
    ndpiStats.incStats(when, ndpi_proto, 0, 0, 1, pkt_len);
    // Note: here we are not currently interested in packet direction, so we tell it is receive
    ndpiStats.incCategoryStats(when, get_ndpi_proto_category(ndpi_proto), 0 /* see above comment */, pkt_len);
    pktStats.incStats(pkt_len);
  };

  inline void incFlagsStats(u_int8_t flags) { pktStats.incFlagStats(flags); };
  inline void incStats(bool ingressPacket, time_t when, u_int16_t eth_proto, u_int16_t ndpi_proto,
		       u_int pkt_len, u_int num_pkts, u_int pkt_overhead) {
#ifdef HAVE_NEDGE
    /* In nedge, we only update the stats periodically with conntrack */
    return;
#endif

    _incStats(ingressPacket, when, eth_proto, ndpi_proto, pkt_len, num_pkts, pkt_overhead);
  };

  inline void incLocalStats(u_int num_pkts, u_int pkt_len, bool localsender, bool localreceiver) {
    localStats.incStats(num_pkts, pkt_len, localsender, localreceiver);
  };

  inline EthStats* getStats()      { return(&ethStats);          };
  inline int get_datalink()        { return(pcap_datalink_type); };
  inline void set_datalink(int l)  { pcap_datalink_type = l;     };
  inline int isRunning()	   { return running;             };
  bool restoreHost(char *host_ip, u_int16_t vlan_id);
  u_int printAvailableInterfaces(bool printHelp, int idx, char *ifname, u_int ifname_len);
  void findFlowHosts(u_int16_t vlan_id,
		     Mac *src_mac, IpAddress *_src_ip, Host **src,
		     Mac *dst_mac, IpAddress *_dst_ip, Host **dst);
  virtual Flow* findFlowByKey(u_int32_t key, AddressTree *allowed_hosts);
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
		     u_int16_t vlan_id,
		     struct ndpi_iphdr *iph,
		     struct ndpi_ipv6hdr *ip6,
		     u_int16_t ipsize, u_int32_t rawsize,
		     const struct pcap_pkthdr *h,
		     const u_char *packet,
		     u_int16_t *ndpiProtocol,
		     Host **srcHost, Host **dstHost, Flow **flow);
  void processFlow(ZMQ_Flow *zflow);
  void processInterfaceStats(sFlowInterfaceStats *stats);
  void dumpFlows();
  void getnDPIStats(nDPIStats *stats, AddressTree *allowed_hosts, const char *host_ip, u_int16_t vlan_id);
  void periodicStatsUpdate();
  virtual void lua(lua_State* vm);
  void getnDPIProtocols(lua_State *vm, ndpi_protocol_category_t filter, bool skip_critical);
  void setnDPIProtocolCategory(u_int16_t protoId, ndpi_protocol_category_t protoCategory);

  int getActiveHostsList(lua_State* vm,
			 u_int32_t *begin_slot,
			 bool walk_all,
			 u_int8_t bridge_iface_idx,
			 AddressTree *allowed_hosts,
			 bool host_details, LocationPolicy location,
			 char *countryFilter, char *mac_filter,
			 u_int16_t vlan_id, char *osFilter,
			 u_int32_t asnFilter, int16_t networkFilter,
			 u_int16_t pool_filter, bool filtered_hosts, bool blacklisted_hosts, bool hide_top_hidden,
       u_int8_t ipver_filter, int proto_filter,
			 char *sortColumn, u_int32_t maxHits,
			 u_int32_t toSkip, bool a2zSortOrder);
  int getActiveHostsGroup(lua_State* vm,
			  u_int32_t *begin_slot,
			  bool walk_all,
			  AddressTree *allowed_hosts,
			  bool host_details, LocationPolicy location,
			  char *countryFilter,
			  u_int16_t vlan_id, char *osFilter,
			  u_int32_t asnFilter, int16_t networkFilter,
			  u_int16_t pool_filter, bool filtered_hosts, u_int8_t ipver_filter,
			  char *groupColumn);
  int getActiveASList(lua_State* vm, const Paginator *p);
  int getActiveCountriesList(lua_State* vm, const Paginator *p);
  int getActiveVLANList(lua_State* vm,
			char *sortColumn, u_int32_t maxHits,
			u_int32_t toSkip, bool a2zSortOrder,
			DetailsLevel details_level);
  int getActiveMacList(lua_State* vm,
		       u_int32_t *begin_slot,
		       bool walk_all,
		       u_int8_t bridge_iface_idx,
		       bool sourceMacsOnly, bool dhcpMacsOnly,
		       const char *manufacturer,
		       char *sortColumn, u_int32_t maxHits,
		       u_int32_t toSkip, bool a2zSortOrder,
		       u_int16_t pool_filter, u_int8_t devtype_filter,
		       u_int8_t location_filter);
  int getActiveMacManufacturers(lua_State* vm,
				u_int8_t bridge_iface_idx,
				bool sourceMacsOnly, bool dhcpMacsOnly,
				u_int32_t maxHits, u_int8_t devtype_filter,
			        u_int8_t location_filter);
  int getActiveDeviceTypes(lua_State* vm,
			   u_int8_t bridge_iface_idx,
			   bool sourceMacsOnly, bool dhcpMacsOnly,
			   u_int32_t maxHits, const char *manufacturer,
			   u_int8_t location_filter);
  int getMacsIpAddresses(lua_State *vm, int idx);
  void getFlowsStats(lua_State* vm);
  void getNetworksStats(lua_State* vm);
#ifdef NOTUSED
  int  getFlows(lua_State* vm, AddressTree *allowed_hosts,
		Host *host, int ndpi_proto, LocationPolicy location,
		char *sortColumn, u_int32_t maxHits,
		u_int32_t toSkip, bool a2zSortOrder);
#endif
  int getFlows(lua_State* vm, AddressTree *allowed_hosts,
		Host *host,
		Paginator *p);
  int getFlowsGroup(lua_State* vm,
		AddressTree *allowed_hosts,
		Paginator *p,
		const char *groupColumn);
  int dropFlowsTraffic(AddressTree *allowed_hosts, Paginator *p);

  virtual void purgeIdle(time_t when);
  u_int purgeIdleFlows();
  u_int purgeIdleHostsMacsASesVlans();

  virtual u_int64_t getNumPackets();
  virtual u_int64_t getNumBytes();
  virtual u_int32_t getNumDroppedPackets() { return 0; };
  virtual u_int     getNumPacketDrops();
  virtual u_int     getNumFlows();
  virtual u_int     getNumL2Devices();
  virtual u_int     getNumHosts();
  virtual u_int     getNumLocalHosts();
  virtual u_int     getNumMacs();
  virtual u_int     getNumHTTPHosts();

  inline u_int64_t  getNumPacketsSinceReset()     { return getNumPackets() - getCheckPointNumPackets(); }
  inline u_int64_t  getNumBytesSinceReset()       { return getNumBytes() - getCheckPointNumBytes(); }
  inline u_int64_t  getNumPacketDropsSinceReset() { return getNumPacketDrops() - getCheckPointNumPacketDrops(); }

  void runHousekeepingTasks();
  Vlan* getVlan(u_int16_t vlanId, bool createIfNotPresent);
  AutonomousSystem *getAS(IpAddress *ipa, bool createIfNotPresent);
  Country* getCountry(const char *country_name, bool createIfNotPresent);
  virtual Mac*  getMac(u_int8_t _mac[6], bool createIfNotPresent);
  virtual Host* getHost(char *host_ip, u_int16_t vlan_id);
  bool getHostInfo(lua_State* vm, AddressTree *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  void findUserFlows(lua_State *vm, char *username);
  void findPidFlows(lua_State *vm, u_int32_t pid);
  void findFatherPidFlows(lua_State *vm, u_int32_t pid);
  void findProcNameFlows(lua_State *vm, char *proc_name);
  void addAllAvailableInterfaces();
  inline bool idle() { return(is_idle); }
  inline u_int16_t getMTU() { return(ifMTU); }
  inline void setIdleState(bool new_state)         { is_idle = new_state;           }
  inline StatsManager  *getStatsManager()          { return statsManager;           }
  inline AlertsManager *getAlertsManager()         { return alertsManager;          }
  void listHTTPHosts(lua_State *vm, char *key);
#ifdef NTOPNG_PRO
  void refreshL7Rules();
  void refreshShapers();
  inline L7Policer* getL7Policer()                     { return(policer);                }
  inline FlowInterfacesStats* getFlowInterfacesStats() { return(flow_interfaces_stats);  }
#endif
  inline HostPools* getHostPools()                     { return(host_pools);    }

  PacketDumper *getPacketDumper(void)                  { return pkt_dumper;     }
  PacketDumperTuntap *getPacketDumperTap(void)         { return pkt_dumper_tap; }
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
  inline void luaHostPoolsStats(lua_State *vm)           { if (host_pools) host_pools->luaStats(vm);           };
  inline void luaHostPoolsVolatileMembers(lua_State *vm) { if (host_pools) host_pools->luaVolatileMembers(vm); };
#endif
  void refreshHostPools();
  inline u_int16_t getHostPool(Host *h) { if(h && host_pools) return host_pools->getPool(h); return NO_HOST_POOL_ID; };
  inline u_int16_t getHostPool(Mac *m)  { if(m && host_pools) return host_pools->getPool(m); return NO_HOST_POOL_ID; };

  bool updateDumpAllTrafficPolicy(void);
  bool updateDumpTrafficDiskPolicy();
  bool updateDumpTrafficTapPolicy();
  int updateDumpTrafficSamplingRate();
  int updateDumpTrafficMaxPktsPerFile();
  int updateDumpTrafficMaxSecPerFile();
  int updateDumpTrafficMaxFiles(void);
  inline bool getDumpTrafficDiskPolicy()      { return(dump_to_disk);       }
  inline bool getDumpTrafficTapPolicy()       { return(dump_to_tap);        }
  inline u_int getDumpTrafficSamplingRate()   { return(dump_sampling_rate); }
  inline u_int getDumpTrafficMaxPktsPerFile() { return(dump_max_pkts_file); }
  inline u_int getDumpTrafficMaxSecPerFile()  { return(dump_max_duration);  }
  inline u_int getDumpTrafficMaxFiles()       { return(dump_max_files);     }
  inline char* getDumpTrafficTapName()        { return(pkt_dumper_tap ? pkt_dumper_tap->getName() : (char*)""); }
  void loadDumpPrefs();
  void loadScalingFactorPrefs();
  void loadPacketsDropsAlertPrefs();
  void getnDPIFlowsCount(lua_State *vm);

  inline void setBridgeLanInterfaceId(u_int32_t v) { bridge_lan_interface_id = v;     };
  inline u_int32_t getBridgeLanInterfaceId()       { return(bridge_lan_interface_id); };
  inline void setBridgeWanInterfaceId(u_int32_t v) { bridge_wan_interface_id = v;     };
  inline u_int32_t getBridgeWanInterfaceId()       { return(bridge_wan_interface_id); };
  inline HostHash* get_hosts_hash()                { return(hosts_hash);              }
  inline MacHash*  get_macs_hash()                 { return(macs_hash);               }
  inline VlanHash*  get_vlans_hash()               { return(vlans_hash);              }
  inline AutonomousSystemHash* get_ases_hash()     { return(ases_hash);               }
  inline CountriesHash* get_countries_hash()       { return(countries_hash);          }
  inline bool is_bridge_interface()                { return(bridge_interface);        }
  inline const char* getLocalIPAddresses()         { return(ip_addresses.c_str());    }
  void addInterfaceAddress(char *addr);
  inline int exec_sql_query(lua_State *vm, char *sql, bool limit_rows, bool wait_for_db_created = true) {
    return(db ? db->exec_sql_query(vm, sql, limit_rows, wait_for_db_created) : -1);
  };
  NetworkStats* getNetworkStats(u_int8_t networkId);
  void allocateNetworkStats();
  void getsDPIStats(lua_State *vm);
#ifdef NTOPNG_PRO
  void updateFlowProfiles();

#ifndef HAVE_NEDGE
  inline FlowProfile* getFlowProfile(Flow *f)  { return(flow_profiles ? flow_profiles->getFlowProfile(f) : NULL);           }
  inline bool checkProfileSyntax(char *filter) { return(flow_profiles ? flow_profiles->checkProfileSyntax(filter) : false); }
#endif

  bool passShaperPacket(TrafficShaper *a_shaper, TrafficShaper *b_shaper, struct pcap_pkthdr *h);
  void initL7Policer();
#endif

  void getFlowsStatus(lua_State *vm);
  void startDBLoop() { if(db) db->startDBLoop(); };
  inline bool createDBSchema()     { if(db) { return db->createDBSchema();     } return false;   };
  inline bool createNprobeDBView() { if(db) { return db->createNprobeDBView(); } return false;   };
#ifdef NTOPNG_PRO
  inline void getFlowDevices(lua_State *vm) {
    if(flow_interfaces_stats) flow_interfaces_stats->luaDeviceList(vm); else lua_newtable(vm);
  };
  inline void getFlowDeviceInfo(lua_State *vm, u_int32_t deviceIP) {
    if(flow_interfaces_stats) flow_interfaces_stats->luaDeviceInfo(vm, deviceIP); else lua_newtable(vm);
  };
#endif
  inline void getSFlowDevices(lua_State *vm) {
    if(interfaceStats) interfaceStats->luaDeviceList(vm); else lua_newtable(vm);
  };
  inline void getSFlowDeviceInfo(lua_State *vm, u_int32_t deviceIP) {
    if(interfaceStats) interfaceStats->luaDeviceInfo(vm, deviceIP); else lua_newtable(vm);
  };

  void refreshHostsAlertPrefs(bool full_refresh);
  int updateHostTrafficPolicy(AddressTree* allowed_networks, char *host_ip, u_int16_t host_vlan);
  int setHostDumpTrafficPolicy(AddressTree* allowed_networks, char *host_ip, u_int16_t host_vlan, bool dump_traffic_to_disk);

  void reloadHideFromTop(bool refreshHosts=true);
  inline void reloadCustomCategories()       { reload_custom_categories = true; }
  bool isHiddenFromTop(Host *host);
  inline virtual bool areTrafficDirectionsSupported() { return(false); };
  inline virtual bool isView() { return(false); };
  bool getMacInfo(lua_State* vm, char *mac);
  bool setMacDeviceType(char *strmac, DeviceType dtype, bool alwaysOverwrite);
  bool setMacOperatingSystem(lua_State* vm, char *mac, OperatingSystem os);
  bool getASInfo(lua_State* vm, u_int32_t asn);
  bool getVLANInfo(lua_State* vm, u_int16_t vlan_id);
  inline void incNumHosts(bool local) { if(local) numLocalHosts++; numHosts++; };
  inline void decNumHosts(bool local) { if(local) numLocalHosts--; numHosts--; };
  inline void incNumL2Devices()       { numL2Devices++; }
  inline void decNumL2Devices()       { numL2Devices--; }
  inline u_int32_t getScalingFactor()       { return(scalingFactor); }
  inline void setScalingFactor(u_int32_t f) { scalingFactor = f;     }
  inline bool isSampledTraffic()            { return((scalingFactor == 1) ? false : true); }
  inline void incAlertLevel()               { alertLevel++;                        }
  inline void decAlertLevel()               { if(--alertLevel < 0) alertLevel = 0; }
  inline int8_t getAlertLevel()             { return(alertLevel);                  }
#ifdef NTOPNG_PRO
  virtual void addToNotifiedInformativeCaptivePortal(u_int32_t client_ip) { ; };
  virtual void addIPToLRUMatches(u_int32_t client_ip, u_int16_t user_pool_id,
				 char *label, int32_t lifetime_sec) { ; };
  void aggregatePartialFlow(Flow *flow);
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

  void topProtocolsAdd(u_int16_t pool_id, u_int16_t protocol, u_int32_t bytes);
  inline void luaTopPoolsProtos(lua_State *vm) { frequentProtocols->luaTopPoolsProtocols(vm); }
  void topMacsAdd(Mac *mac, u_int16_t protocol, u_int32_t bytes);
  inline bool isDynamicInterface()                { return(is_dynamic_interface);            };
  inline void setDynamicInterface()               { is_dynamic_interface = true;             };
  inline void luaTopMacsProtos(lua_State *vm) { frequentMacs->luaTopMacsProtocols(vm); }
  inline MDNS* getMDNS() { return(mdns); }
  inline NetworkDiscovery* getNetworkDiscovery() { return(discovery); }
  inline void incPoolNumHosts(u_int16_t id, bool isInlineCall) {
    if (host_pools) host_pools->incNumHosts(id, isInlineCall);
  };
  inline void decPoolNumHosts(u_int16_t id, bool isInlineCall) {
    if (host_pools) host_pools->decNumHosts(id, isInlineCall);
  };
  inline void incPoolNumL2Devices(u_int16_t id, bool isInlineCall) {
    if (host_pools) host_pools->incNumL2Devices(id, isInlineCall);
  };
  inline void decPoolNumL2Devices(u_int16_t id, bool isInlineCall) {
    if (host_pools) host_pools->decNumL2Devices(id, isInlineCall);
  };
  Host* findHostByIP(AddressTree *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  inline bool do_dump_unknown_traffic() { return(dump_unknown_traffic); }
  inline bool do_dump_all_traffic()     { return(dump_unknown_traffic); }
#ifdef HAVE_NINDEX
  NIndexFlowDB* getNindex();
#endif
  inline TimeSeriesExporter* getTSExporter() { if(!tsExporter) tsExporter = new TimeSeriesExporter(this); return(tsExporter); }
  inline uint32_t getMaxSpeed()              { return(ifSpeed); }
  virtual void sendTermination()             { ; }
  virtual bool read_from_pcap_dump()         { return(false); };
};

#endif /* _NETWORK_INTERFACE_H_ */
