/*
 *
 * (C) 2013-17 - ntop.org
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
class DB;
class Paginator;

#ifdef NTOPNG_PRO
class AggregatedFlow;
class AggregatedFlowHash;
class L7Policer;
class FlowInterfacesStats;
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
class NetworkInterface {
 protected:
  char *ifname, *ifDescription;
  const char *customIftype;
  u_int8_t alertLevel, purgeRuns;

  /* Disaggregations */
  u_int16_t numVirtualInterfaces;
  FlowHashingEnum flowHashingMode;
  FlowHashing *flowHashing;
  MDNS mdns;
  string ip_addresses;
  int id;
  bool bridge_interface;
#ifdef NTOPNG_PRO
  L7Policer *policer;
  FlowProfiles  *flow_profiles, *shadow_flow_profiles;
  FlowInterfacesStats *flow_interfaces_stats;
  AggregatedFlowHash *aggregated_flows_hash; /**< Hash used to store aggregated flows information. */
#endif
  EthStats ethStats;
  u_int32_t arp_requests, arp_replies;
  ICMPstats icmp_v4, icmp_v6;
  LocalTrafficStats localStats;
  int pcap_datalink_type; /**< Datalink type of pcap. */
  pthread_t pollLoop;
  bool pollLoopCreated, has_too_many_hosts, has_too_many_flows, mtuWarningShown;
  u_int32_t ifSpeed, numL2Devices, numHosts, numLocalHosts, scalingFactor;
  u_int64_t checkpointPktCount, checkpointBytesCount, checkpointPktDropCount; /* Those will hold counters at checkpoints */
  u_int16_t ifMTU;
  int cpu_affinity; /**< Index of physical core where the network interface works. */
  nDPIStats ndpiStats;
  PacketStats pktStats;
  FlowHash *flows_hash; /**< Hash used to store flows information. */
  u_int32_t last_remote_pps, last_remote_bps;

  /* Sub-interface views */
  u_int8_t numSubInterfaces;
  NetworkInterface *subInterfaces[MAX_NUM_VIEW_INTERFACES];

  /* Lua */
  bool user_scripts_reload_inline, user_scripts_reload_periodic;
  lua_State *L_user_scripts_inline, *L_user_scripts_periodic;

  /* Second update */
  u_int64_t lastSecTraffic,
    lastMinuteTraffic[60],    /* Delta bytes (per second) of the last minute */
    currentMinuteTraffic[60]; /* Delta bytes (per second) of the current minute */
  time_t lastSecUpdate;
  u_int nextFlowAggregation;
  TcpFlowStats tcpFlowStats;
  TcpPacketStats tcpPacketStats;

  u_int64_t zmq_initial_bytes, zmq_initial_pkts;

  /* Mac */
  MacHash *macs_hash; /**< Hash used to store MAC information. */

  /* Autonomous Systems */
  AutonomousSystemHash *ases_hash; /**< Hash used to store Autonomous Systems information. */

  /* Vlans */
  VlanHash *vlans_hash; /**< Hash used to store Vlans information. */

  /* Hosts */
  HostHash *hosts_hash; /**< Hash used to store hosts information. */
  bool purge_idle_flows_hosts, sprobe_interface, inline_interface,
    dump_all_traffic, dump_to_tap, dump_to_disk, dump_unknown_traffic, dump_security_packets;
  DB *db;
  u_int dump_sampling_rate, dump_max_pkts_file, dump_max_duration, dump_max_files;
  StatsManager  *statsManager;
  AlertsManager *alertsManager;
  HostPools *host_pools;
  bool has_vlan_packets, has_mac_addresses;
  struct ndpi_detection_module_struct *ndpi_struct;
  time_t last_pkt_rcvd, last_pkt_rcvd_remote, /* Meaningful only for ZMQ interfaces */
    next_idle_flow_purge, next_idle_host_purge;
  bool running, is_idle;
  PacketDumper *pkt_dumper;
  PacketDumperTuntap *pkt_dumper_tap;
  NetworkStats *networkStats;
  InterfaceStatsHash *interfaceStats;

  lua_State* initUserScriptsInterpreter(const char *lua_file, const char *context);
  void termLuaInterpreter();
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
		bool *new_flow);
  int sortHosts(struct flowHostRetriever *retriever,
		u_int8_t bridge_iface_idx,
		AddressTree *allowed_hosts,
		bool host_details,
		LocationPolicy location,
		char *countryFilter, char *mac_filter,
		u_int16_t vlan_id, char *osFilter,
		u_int32_t asnFilter, int16_t networkFilter,
		u_int16_t pool_filter, bool filtered_hosts, u_int8_t ipver_filter, int proto_filter,
		bool hostMacsOnly, char *sortColumn);
  int sortASes(struct flowHostRetriever *retriever,
	       char *sortColumn);
  int sortVLANs(struct flowHostRetriever *retriever,
		char *sortColumn);
  int sortMacs(struct flowHostRetriever *retriever,
	       u_int8_t bridge_iface_idx,
	       u_int16_t vlan_id, bool sourceMacsOnly,
	       bool hostMacsOnly, const char *manufacturer,
	       char *sortColumn, u_int16_t pool_filter);

  bool isNumber(const char *str);
  bool validInterface(char *name);
  bool isInterfaceUp(char *name);
  bool checkIdle();
  void dumpPacketDisk(const struct pcap_pkthdr *h, const u_char *packet, dump_reason reason);
  void dumpPacketTap(const struct pcap_pkthdr *h, const u_char *packet, dump_reason reason);
  virtual u_int32_t getNumDroppedPackets() { return 0; };
  bool walker(WalkerType wtype,
	      bool (*walker)(GenericHashEntry *h, void *user_data),
	      void *user_data);

  void disablePurge(bool on_flows);
  void enablePurge(bool on_flows);
  u_int32_t getHostsHashSize();
  u_int32_t getASesHashSize();
  u_int32_t getVLANsHashSize();
  u_int32_t getFlowsHashSize();
  u_int32_t getMacsHashSize();
  void sumStats(TcpFlowStats *_tcpFlowStats, EthStats *_ethStats,
		LocalTrafficStats *_localStats, nDPIStats *_ndpiStats,
		PacketStats *_pktStats, TcpPacketStats *_tcpPacketStats);

  Host* findHostsByIP(AddressTree *allowed_hosts,
		      char *host_ip, u_int16_t vlan_id);

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

  void checkAggregationMode();
  inline void setCPUAffinity(int core_id)      { cpu_affinity = core_id; };
  virtual void startPacketPolling();
  virtual void shutdown();
  virtual void cleanup();
  virtual char *getScriptName()                { return NULL;   }
  virtual char *getEndpoint(u_int8_t id)       { return NULL;   };
  virtual bool set_packet_filter(char *filter) { return(false); };
  virtual void incrDrops(u_int32_t num)        { ; }
  /* calling virtual in constructors/destructors should be avoided
     See C++ FAQ Lite covers this in section 23.7
  */
  inline virtual bool isPacketInterface()      { return(strcmp(get_type(), CONST_INTERFACE_TYPE_FLOW) != 0); }
  inline virtual const char* get_type()        { return(customIftype ? customIftype : CONST_INTERFACE_TYPE_UNKNOWN); }
  inline FlowHash *get_flows_hash()            { return flows_hash;     }
  inline TcpFlowStats* getTcpFlowStats()       { return(&tcpFlowStats); }
  inline virtual bool is_ndpi_enabled()        { return(true);          }
  inline u_int  getNumnDPIProtocols()          { return(ndpi_get_num_supported_protocols(ndpi_struct)); };
  inline time_t getTimeLastPktRcvd()           { return(last_pkt_rcvd ? last_pkt_rcvd : last_pkt_rcvd_remote); };
  inline void  setTimeLastPktRcvd(time_t t)    { last_pkt_rcvd = t; };
  inline ndpi_protocol_category_t get_ndpi_proto_category(ndpi_protocol proto) { return(ndpi_get_proto_category(ndpi_struct, proto)); };
  ndpi_protocol_category_t get_ndpi_proto_category(u_int protoid);
  inline char* get_ndpi_proto_name(u_int id)   { return(ndpi_get_proto_name(ndpi_struct, id));   };
  inline int   get_ndpi_proto_id(char *proto)  { return(ndpi_get_protocol_id(ndpi_struct, proto));   };
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
  int dumpAggregatedFlow(AggregatedFlow *f);
#endif
  int dumpDBFlow(time_t when, Flow *f);
  int dumpEsFlow(time_t when, Flow *f);
  int dumpLsFlow(time_t when, Flow *f);
  int dumpLocalHosts2redis(bool disable_purge);
  inline void incRetransmittedPkts(u_int32_t num)   { tcpPacketStats.incRetr(num); };
  inline void incOOOPkts(u_int32_t num)             { tcpPacketStats.incOOO(num);  };
  inline void incLostPkts(u_int32_t num)            { tcpPacketStats.incLost(num); };
  inline void resetSecondTraffic() {
    memset(currentMinuteTraffic, 0, sizeof(currentMinuteTraffic)); lastSecTraffic = 0, lastSecUpdate = 0;
  };
  void updateSecondTraffic(time_t when);
  void checkPointCounters(bool drops_only);
  u_int64_t getCheckPointNumPackets();
  u_int64_t getCheckPointNumBytes();
  u_int32_t getCheckPointNumPacketDrops();
  inline void incFlagsStats(u_int8_t flags) { pktStats.incFlagStats(flags); };
  inline void incStats(time_t when, u_int16_t eth_proto, u_int16_t ndpi_proto,
		       u_int pkt_len, u_int num_pkts, u_int pkt_overhead) {
    ethStats.incStats(eth_proto, num_pkts, pkt_len, pkt_overhead);
    ndpiStats.incStats(when, ndpi_proto, 0, 0, 1, pkt_len);
    pktStats.incStats(pkt_len);
    if(lastSecUpdate == 0) lastSecUpdate = when; else if(lastSecUpdate != when) updateSecondTraffic(when);
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
  Flow* findFlowByKey(u_int32_t key, AddressTree *allowed_hosts);
  bool findHostsByName(lua_State* vm, AddressTree *allowed_hosts, char *key);
  bool dissectPacket(u_int8_t bridge_iface_idx,
		     u_int8_t *sender_mac, /* Non NULL only for NFQUEUE interfaces */
		     const struct pcap_pkthdr *h, const u_char *packet,
		     u_int16_t *ndpiProtocol,
		     Host **srcHost, Host **dstHost, Flow **flow);
  bool processPacket(u_int8_t bridge_iface_idx,
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
  void getnDPIProtocols(lua_State *vm);
  void getnDPIProtocols(lua_State *vm, ndpi_protocol_category_t filter);

  /**
   * @brief Returns host statistics during latest activity
   * @details Local hosts statistics may be flushed to redis when they become inactive.
   *          When they become active again, redis-stored statistics are restored.
   *          There is a limited number of cases that only need host statistics during
   *          the latest activity. This is for example true when computing
   *          minute-by-minute top statistics.
   *
   *          The function is handy to retrieve compact, unsorted host statistics
   *          without including deserialized values for total local host bytes (sent and received).
   *
   * @param vm The lua state.
   * @param allowed_hosts A patricia tree containing allowed hosts.
   */
  int getLatestActivityHostsList(lua_State* vm,
				 AddressTree *allowed_hosts);
  int getActiveHostsList(lua_State* vm,
			 u_int8_t bridge_iface_idx,
			 AddressTree *allowed_hosts,
			 bool host_details, LocationPolicy location,
			 char *countryFilter, char *mac_filter,
			 u_int16_t vlan_id, char *osFilter,
			 u_int32_t asnFilter, int16_t networkFilter,
			 u_int16_t pool_filter, bool filtered_hosts, u_int8_t ipver_filter, int proto_filter,
			 char *sortColumn, u_int32_t maxHits,
			 u_int32_t toSkip, bool a2zSortOrder);
  int getActiveHostsGroup(lua_State* vm,
			  AddressTree *allowed_hosts,
			  bool host_details, LocationPolicy location,
			  char *countryFilter,
			  u_int16_t vlan_id, char *osFilter,
			  u_int32_t asnFilter, int16_t networkFilter,
			  u_int16_t pool_filter, bool filtered_hosts, u_int8_t ipver_filter,
			  bool hostsOnly, char *groupColumn);
  int getActiveASList(lua_State* vm,
		      char *sortColumn, u_int32_t maxHits,
		      u_int32_t toSkip, bool a2zSortOrder,
		      DetailsLevel details_level);
  int getActiveVLANList(lua_State* vm,
			char *sortColumn, u_int32_t maxHits,
			u_int32_t toSkip, bool a2zSortOrder,
			DetailsLevel details_level);
  int getActiveMacList(lua_State* vm,
		       u_int8_t bridge_iface_idx,
		       u_int16_t vlan_id,
		       bool sourceMacsOnly,
		       bool hostMacsOnly, const char *manufacturer,
		       char *sortColumn, u_int32_t maxHits,
		       u_int32_t toSkip, bool a2zSortOrder,
		       u_int16_t pool_filter);
  int getActiveMacManufacturers(lua_State* vm,
				u_int8_t bridge_iface_idx,
				u_int16_t vlan_id,
				bool sourceMacsOnly,
				bool hostMacsOnly, u_int32_t maxHits);
  void getFlowsStats(lua_State* vm);
  void getNetworksStats(lua_State* vm);
#ifdef NOTUSED
  int  getFlows(lua_State* vm, AddressTree *allowed_hosts,
		Host *host, int ndpi_proto, LocationPolicy location,
		char *sortColumn, u_int32_t maxHits,
		u_int32_t toSkip, bool a2zSortOrder);
#endif
  int  getFlows(lua_State* vm, AddressTree *allowed_hosts,
		Host *host,
		Paginator *p);

  void purgeIdle(time_t when);
  u_int purgeIdleFlows();
  u_int purgeIdleHostsMacsASesVlans();

  u_int64_t getNumPackets();
  u_int64_t getNumBytes();
  u_int getNumPacketDrops();
  u_int getNumFlows();
  u_int getNumHosts();
  u_int getNumLocalHosts();
  u_int getNumMacs();
  u_int getNumHTTPHosts();

  void runHousekeepingTasks();
  Mac*  getMac(u_int8_t _mac[6], u_int16_t vlanId, bool createIfNotPresent);
  Vlan* getVlan(u_int16_t vlanId, bool createIfNotPresent);
  AutonomousSystem *getAS(IpAddress *ipa, bool createIfNotPresent);
  Host* getHost(char *host_ip, u_int16_t vlan_id);
  bool getHostInfo(lua_State* vm, AddressTree *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool correlateHostActivity(lua_State* vm, AddressTree *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool similarHostActivity(lua_State* vm, AddressTree *allowed_hosts, char *host_ip, u_int16_t vlan_id);
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
  inline L7Policer* getL7Policer()                     { return(policer);     }
  inline FlowInterfacesStats* getFlowInterfacesStats() { return(flow_interfaces_stats);  }
#endif
  inline HostPools* getHostPools()         { return(host_pools);  }

  PacketDumper *getPacketDumper(void)      { return pkt_dumper; }
  PacketDumperTuntap *getPacketDumperTap(void)      { return pkt_dumper_tap; }

#ifdef NTOPNG_PRO
  void updateHostsL7Policy(u_int16_t host_pool_id);
  void updateFlowsL7Policy();
  void resetPoolsStats();
  inline void luaHostPoolsStats(lua_State *vm)           { if (host_pools) host_pools->luaStats(vm);           };
  inline void luaHostPoolsVolatileMembers(lua_State *vm) { if (host_pools) host_pools->luaVolatileMembers(vm); };
#endif
  void refreshHostPools();
  inline u_int16_t getHostPool(Host *h) { if(h && host_pools) return host_pools->getPool(h); return NO_HOST_POOL_ID; };

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
  void getnDPIFlowsCount(lua_State *vm);

  inline HostHash* get_hosts_hash()            { return(hosts_hash); }
  inline MacHash*  get_macs_hash()             { return(macs_hash);  }
  inline VlanHash*  get_vlans_hash()           { return(vlans_hash); }
  inline AutonomousSystemHash* get_ases_hash() { return(ases_hash);  }
  inline bool is_bridge_interface()  { return(bridge_interface); }
  inline const char* getLocalIPAddresses() { return(ip_addresses.c_str()); }
  void addInterfaceAddress(char *addr);
  inline int exec_sql_query(lua_State *vm, char *sql, bool limit_rows, bool wait_for_db_created = true) {
    return(db ? db->exec_sql_query(vm, sql, limit_rows, wait_for_db_created) : -1);
  };
  NetworkStats* getNetworkStats(u_int8_t networkId);
  void allocateNetworkStats();
  void getsDPIStats(lua_State *vm);
  inline u_int64_t* getLastMinuteTrafficStats() { return((u_int64_t*)lastMinuteTraffic); }
#ifdef NTOPNG_PRO
  void updateFlowProfiles();
  inline FlowProfile* getFlowProfile(Flow *f)  { return(flow_profiles ? flow_profiles->getFlowProfile(f) : NULL);           }
  inline bool checkProfileSyntax(char *filter) { return(flow_profiles ? flow_profiles->checkProfileSyntax(filter) : false); }

  bool passShaperPacket(int a_shaper_id, int b_shaper_id, struct pcap_pkthdr *h);
  void initL7Policer();
#endif

  void getFlowsStatus(lua_State *vm);
  void startDBLoop() { if(db) db->startDBLoop(); };
  inline bool createDBSchema() {if(db) {return db->createDBSchema();} return false;};
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
  int engageReleaseHostAlert(AddressTree* allowed_networks, char *host_ip, u_int16_t host_vlan, bool engage,
			     AlertEngine alert_engine,
			     char *engaged_alert_id, AlertType alert_type, AlertLevel alert_severity, const char *alert_json);

  int luaEvalFlow(Flow *f, const LuaCallback cb);
  inline void forceLuaInterpreterReload() { user_scripts_reload_inline = user_scripts_reload_periodic = true; };
  inline virtual bool isView() { return(false); };
  bool getMacInfo(lua_State* vm, char *mac, u_int16_t vlan_id);
  bool getASInfo(lua_State* vm, u_int32_t asn);
  bool getVLANInfo(lua_State* vm, u_int16_t vlan_id);
  inline void incNumHosts(bool local) { if(local) numLocalHosts++; numHosts++; };
  inline void decNumHosts(bool local) { if(local) numLocalHosts--; numHosts--; };
  inline void incNumL2Devices()       { numL2Devices++; }
  inline void decNumL2Devices()       { numL2Devices--; }
  inline u_int32_t getNumL2Devices() { return(numL2Devices); }
  inline u_int32_t getScalingFactor()       { return(scalingFactor); }
  inline void setScalingFactor(u_int32_t f) { scalingFactor = f;     }
  inline bool isSampledTraffic()            { return((scalingFactor == 1) ? false : true); }
  inline void incAlertLevel()               { alertLevel++;                        }
  inline void decAlertLevel()               { if(--alertLevel < 0) alertLevel = 0; }
  inline int8_t getAlertLevel()             { return(alertLevel);                  }
#ifdef NTOPNG_PRO
  virtual void addIPToLRUMatches(u_int32_t client_ip, u_int16_t user_pool_id,
				 char *label, int32_t lifetime_sec) { ; };
  void aggregatePartialFlow(Flow *flow);
#endif

  inline char* mdnsResolveIPv4(u_int32_t ipv4addr /* network byte order */,
			       char *buf, u_int buf_len, u_int timeout_sec = 2) {
    return(mdns.resolveIPv4(ipv4addr, buf, buf_len, timeout_sec));
  }
};

#endif /* _NETWORK_INTERFACE_H_ */
