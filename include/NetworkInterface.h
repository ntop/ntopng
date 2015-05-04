/*
 *
 * (C) 2013-15 - ntop.org
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
class DB;
/**
 * @struct ether80211q
 * @details [long description]
 *
 * @param  [description]
 * @return [description]
 */
typedef struct ether80211q {
  u_int16_t vlanId;
  u_int16_t protoType;
} Ether80211q;

typedef struct {
  u_int32_t pid, father_pid;
  char name[48], father_name[48], user_name[48];
  u_int32_t actual_memory, peak_memory;
  float average_cpu_load, percentage_iowait_time;
  u_int32_t num_vm_page_faults;
} ProcessInfo;

typedef struct zmq_flow {
  IpAddress src_ip, dst_ip;
  u_int16_t src_port, dst_port, l7_proto;
  u_int16_t vlan_id, pkt_sampling_rate;
  u_int8_t l4_proto, tcp_flags;
  u_int32_t in_pkts, in_bytes, out_pkts, out_bytes;
  u_int32_t first_switched, last_switched;
  json_object *additional_fields;
  u_int8_t src_mac[6], dst_mac[6], direction, source_id;

  /* EPP Extensions */
  char epp_server_name[48], epp_registrar_name[48], epp_cmd_args[64], epp_reason_str[16];
  u_int8_t epp_cmd;
  int epp_rsp_code;

  /* Process Extensions */
  ProcessInfo src_process, dst_process;
} ZMQ_Flow;

struct vm_ptree {
  lua_State* vm;
  patricia_tree_t *ptree;
};

struct aggregation_walk_hosts_info {
  lua_State* vm;
  u_int16_t family_id;
  char *host;
  patricia_tree_t *allowed_hosts;
};

struct flow_details_info {
  lua_State* vm;
  patricia_tree_t *allowed_hosts;
  Host *h;
};

struct active_flow_stats {
  u_int32_t num_flows, 
    ndpi_bytes[NDPI_MAX_SUPPORTED_PROTOCOLS+NDPI_MAX_NUM_CUSTOM_PROTOCOLS],
    breeds_bytes[NUM_BREEDS];
};

struct ndpi_protocols_aggregation {
  NDPI_PROTOCOL_BITMASK families;
  NDPI_PROTOCOL_BITMASK aggregations; /* Jeopardized */
};

#ifdef NTOPNG_PRO
class L7Policer;
#endif

/** @class NetworkInterface
 *  @brief Main class of network interface of ntopng.
 *  @details .......
 *
 *  @ingroup NetworkInterface
 *
 */
class NetworkInterface {
 protected:
  bool flow_dump;
  char *ifname; /**< Network interface name.*/
  int id;
#ifdef NTOPNG_PRO
  L7Policer *policer;
#endif
  EthStats ethStats;
  LocalTrafficStats localStats;
  int pcap_datalink_type; /**< Datalink type of pcap.*/
  pthread_t pollLoop;
  int cpu_affinity; /**< Index of physical core where the network interface works.*/
  NdpiStats ndpiStats;
  PacketStats pktStats;
  FlowHash *flows_hash; /**< Hash used to memorize the flows information.*/
  /* Hosts */
  HostHash *hosts_hash; /**< Hash used to memorize the hosts information.*/
  /* String hash (Aggregation) */
  StringHash *strings_hash; /**< Hash used to memorize the aggregation information.*/
  bool purge_idle_flows_hosts, sprobe_interface, inline_interface,
    dump_all_traffic, dump_to_tap, dump_to_disk, dump_unknown_to_disk, dump_security_to_disk;
  DB *db;
  u_int dump_sampling_rate, dump_max_pkts_file, dump_max_duration, dump_max_files;
  StatsManager *statsManager;
  NetworkInterfaceView *view;
  bool has_vlan_packets;
  struct ndpi_detection_module_struct *ndpi_struct;
  time_t last_pkt_rcvd, next_idle_flow_purge, next_idle_host_purge, next_idle_aggregated_host_purge;
  bool running, is_idle;
  PacketDumper *pkt_dumper;
  PacketDumperTuntap *pkt_dumper_tap;

  void deleteDataStructures();
  Flow* getFlow(u_int8_t *src_eth, u_int8_t *dst_eth, u_int16_t vlan_id,
  		IpAddress *src_ip, IpAddress *dst_ip,
  		u_int16_t src_port, u_int16_t dst_port,
		u_int8_t l4_proto,
		bool *src2dst_direction,
		time_t first_seen, time_t last_seen,
		bool *new_flow);
  bool isNumber(const char *str);
  bool validInterface(char *name);
  void process_epp_flow(ZMQ_Flow *zflow, Flow *flow);
  bool isInterfaceUp(char *name);
  bool checkIdle();
  void dumpPacketDisk(const struct pcap_pkthdr *h, const u_char *packet, dump_reason reason);
  void dumpPacketTap(const struct pcap_pkthdr *h, const u_char *packet, dump_reason reason);

 public:
  /**
  * @brief A Constructor
  * @details Creating a new NeworkInteface with all instance variables set to NULL.
  *
  * @return A new instance of NetworkInteface.
  */
  NetworkInterface();
  NetworkInterface(const char *name);
  virtual ~NetworkInterface();

  virtual void startPacketPolling();
  virtual void shutdown();
  virtual void cleanup();
  virtual u_int getNumDroppedPackets()         { return 0;      };
  virtual char *getScriptName()                { return NULL;   }
  virtual char *getEndpoint(u_int8_t id)       { return NULL;   };
  virtual bool set_packet_filter(char *filter) { return(false); };
  virtual void incrDrops(u_int32_t num)        { ; }
  inline virtual bool is_packet_interface()    { return(true); }
  inline virtual const char* get_type()        { return(CONST_INTERFACE_TYPE_UNKNOWN); }
  inline virtual bool is_ndpi_enabled()        { return(true); }
  inline u_int  getNumnDPIProtocols()          { return(ndpi_get_num_supported_protocols(ndpi_struct)); };
  inline time_t getTimeLastPktRcvd()           { return(last_pkt_rcvd); };
  inline void  setTimeLastPktRcvd(time_t t)    { last_pkt_rcvd = t; };
  inline char* get_ndpi_proto_name(u_int id)   { return(ndpi_get_proto_name(ndpi_struct, id));   };
  inline char* get_ndpi_proto_breed_name(u_int id) { return(ndpi_get_proto_breed_name(ndpi_struct,
										      ndpi_get_proto_breed(ndpi_struct,
													   id))); };
  inline u_int get_flow_size()                 { return(ndpi_detection_get_sizeof_ndpi_flow_struct()); };
  inline u_int get_size_id()                   { return(ndpi_detection_get_sizeof_ndpi_id_struct());   };
  inline char* get_name()                      { return(ifname);                                       };
  inline int get_id()                          { return(id);                                           };
  inline bool get_sprobe_interface()        { return sprobe_interface; }
  inline bool get_inline_interface()        { return inline_interface; }
  inline bool get_has_vlan_packets()        { return has_vlan_packets; }
  inline NetworkInterfaceView *get_view(void) { return view; }
  inline void set_view(NetworkInterfaceView *v) { view = v; }
  inline bool  hasSeenVlanTaggedPackets()      { return(has_vlan_packets); }
  inline void  setSeenVlanTaggedPackets()      { has_vlan_packets = true; }
  inline struct ndpi_detection_module_struct* get_ndpi_struct() { return(ndpi_struct);         };
  inline bool is_sprobe_interface()            { return(sprobe_interface); };
  inline bool is_purge_idle_interface()        { return(purge_idle_flows_hosts);               };
  inline void enable_sprobe()                  { sprobe_interface = true; };
  int dumpFlow(time_t when, bool partial_dump, Flow *f);
  int dumpDBFlow(time_t when, bool partial_dump, Flow *f);
  int dumpEsFlow(time_t when, bool partial_dump, Flow *f);
  inline bool getInterfaceFlowDumpPolicy(){return flow_dump;}
  inline void setInterfaceFlowDumpPolicy(bool b){flow_dump=b;}
  inline void incStats(u_int16_t eth_proto, u_int16_t ndpi_proto, u_int pkt_len, u_int num_pkts, u_int pkt_overhead) {
    ethStats.incStats(eth_proto, num_pkts, pkt_len, pkt_overhead);
    ndpiStats.incStats(ndpi_proto, 0, 0, 1, pkt_len);
    pktStats.incStats(pkt_len);
  };
  inline EthStats* getStats()      { return(&ethStats);          };
  inline int get_datalink()        { return(pcap_datalink_type); };
  inline void set_datalink(int l)  { pcap_datalink_type = l;     };
  inline int isRunning()	   { return running;             };
  inline void set_cpu_affinity(int core_id) { cpu_affinity = core_id; if (running) Utils::setThreadAffinity(pollLoop, cpu_affinity); };
  bool restoreHost(char *host_ip);
  void enableInterfaceView();
  u_int printAvailableInterfaces(bool printHelp, int idx, char *ifname, u_int ifname_len);
  void findFlowHosts(u_int16_t vlan_id,
		     u_int8_t src_mac[6], IpAddress *_src_ip, Host **src,
		     u_int8_t dst_mac[6], IpAddress *_dst_ip, Host **dst);
  Flow* findFlowByKey(u_int32_t key, patricia_tree_t *allowed_hosts);
  void findHostsByName(lua_State* vm, patricia_tree_t *allowed_hosts, char *key);
  void flushHostContacts();
  bool packet_dissector(const struct pcap_pkthdr *h, const u_char *packet,
			int *egress_shaper_id);
  bool packetProcessing(const struct timeval *when,
			const u_int64_t time,
			struct ndpi_ethhdr *eth,
			u_int16_t vlan_id,
			struct ndpi_iphdr *iph,
			struct ndpi_ip6_hdr *ip6,
			u_int16_t ipsize, u_int16_t rawsize,
			const struct pcap_pkthdr *h,
			const u_char *packet,
			int *egress_shaper_id);
  void flow_processing(ZMQ_Flow *zflow);
  void dumpFlows();
  void getnDPIStats(NdpiStats *stats);
  void updateFlowsL7Policy();
  void updateHostStats();
  virtual void lua(lua_State* vm);
  void getnDPIProtocols(lua_State *vm);
  void getActiveHostsList(lua_State* vm, vm_ptree *vp, bool host_details);
  void getFlowsStats(lua_State* vm);
  void getActiveFlowsList(lua_State* vm, char *host_ip, u_int vlan_id, patricia_tree_t *allowed_hosts);
  void getFlowPeersList(lua_State* vm, patricia_tree_t *allowed_hosts, char *numIP, u_int16_t vlanId);
  void purgeIdle(time_t when);
  u_int purgeIdleFlows();
  u_int purgeIdleHosts();
  u_int purgeIdleAggregatedHosts();

  inline u_int64_t getNumPackets()  { return(ethStats.getNumPackets());      };
  inline u_int64_t getNumBytes()    { return(ethStats.getNumBytes());        };
  u_int getNumFlows();
  u_int getNumHosts();
  u_int getNumHTTPHosts();
  u_int getNumAggregations();

  void runHousekeepingTasks();
  Host* findHostByMac(u_int8_t mac[6], u_int16_t vlanId,
		      bool createIfNotPresent);
  Host* getHost(char *host_ip, u_int16_t vlan_id);
  StringHost* getAggregatedHost(char *host_name);
  bool getHostInfo(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  void getActiveAggregatedHostsList(lua_State* vm, struct aggregation_walk_hosts_info *info);
  bool getAggregatedHostInfo(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip);
  bool getAggregationFamilies(lua_State* vm, struct ndpi_protocols_aggregation *agg);
  bool compareAggregationFamilies(lua_State* vm, struct ndpi_protocols_aggregation *agg);
  bool getAggregationsForHost(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip);
  bool correlateHostActivity(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool similarHostActivity(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  StringHost* findHostByString(patricia_tree_t *allowed_hosts,
			       char *keyname, u_int16_t family_id,
			       bool createIfNotPresent);
  inline u_int getNumAggregatedHosts() { return(strings_hash->getNumEntries()); }
  void findUserFlows(lua_State *vm, char *username);
  void findPidFlows(lua_State *vm, u_int32_t pid);
  void findFatherPidFlows(lua_State *vm, u_int32_t pid);
  void findProcNameFlows(lua_State *vm, char *proc_name);
  void addAllAvailableInterfaces();
  inline bool idle() { return(is_idle); }
  inline void setIdleState(bool new_state) { is_idle = new_state; }
  inline StatsManager *getStatsManager()   { return statsManager; }
  void listHTTPHosts(lua_State *vm, char *key);
#ifdef NTOPNG_PRO
  void refreshL7Rules();
  inline L7Policer* getL7Policer()         { return(policer);     }
#endif

  PacketDumper *getPacketDumper(void)      { return pkt_dumper; }
  PacketDumperTuntap *getPacketDumperTap(void)      { return pkt_dumper_tap; }
  void updateHostsL7Policy();
  bool updateDumpAllTrafficPolicy(void);
  bool updateDumpTrafficDiskPolicy();
  bool updateDumpTrafficTapPolicy();
  int updateDumpTrafficSamplingRate();
  int updateDumpTrafficMaxPktsPerFile();
  int updateDumpTrafficMaxSecPerFile();
  int updateDumpTrafficMaxFiles(void);
  inline bool getDumpTrafficDiskPolicy()      { return(dump_to_disk); }
  inline bool getDumpTrafficTapPolicy()       { return(dump_to_tap); }
  inline u_int getDumpTrafficSamplingRate()   { return(dump_sampling_rate); }
  inline u_int getDumpTrafficMaxPktsPerFile() { return(dump_max_pkts_file); }
  inline u_int getDumpTrafficMaxSecPerFile()  { return(dump_max_duration); }
  inline u_int getDumpTrafficMaxFiles()       { return(dump_max_files); }

  string getDumpTrafficTapName();
  void loadDumpPrefs();
  void getnDPIFlowsCount(lua_State *vm);

  Host* findHostsByIP(patricia_tree_t *allowed_hosts,
		      char *host_ip, u_int16_t vlan_id);
  inline void updateLocalStats(u_int num_pkts, u_int pkt_len, bool localsender, bool localreceiver) { 
    localStats.incStats(num_pkts, pkt_len, localsender, localreceiver); }

  inline HostHash* get_hosts_hash() { return(hosts_hash); }
};

#endif /* _NETWORK_INTERFACE_H_ */
