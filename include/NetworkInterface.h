/*
 *
 * (C) 2013-16 - ntop.org
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
  char *ifname; /**< Network interface name.*/
  string ip_addresses;
  int id;
  bool bridge_interface, has_mesh_networks_traffic;
#ifdef NTOPNG_PRO
  L7Policer *policer;
  FlowProfiles  *flow_profiles;
#endif
  EthStats ethStats;
  LocalTrafficStats localStats;
  int pcap_datalink_type; /**< Datalink type of pcap.*/
  pthread_t pollLoop;
  bool pollLoopCreated;
  u_int32_t ifSpeed;
  u_int16_t ifMTU;
  bool mtuWarningShown;
  int cpu_affinity; /**< Index of physical core where the network interface works.*/
  nDPIStats ndpiStats;
  PacketStats pktStats;
  FlowHash *flows_hash; /**< Hash used to memorize the flows information.*/

  /* Second update */
  u_int64_t lastSecTraffic,
    lastMinuteTraffic[60],    /* Delta bytes (per second) of the last minute */
    currentMinuteTraffic[60]; /* Delta bytes (per second) of the current minute */
  time_t lastSecUpdate;

  /* Hosts */
  HostHash *hosts_hash; /**< Hash used to memorize the hosts information.*/
  bool purge_idle_flows_hosts, sprobe_interface, inline_interface,
    dump_all_traffic, dump_to_tap, dump_to_disk, dump_unknown_traffic, dump_security_packets;
  DB *db;
  u_int dump_sampling_rate, dump_max_pkts_file, dump_max_duration, dump_max_files;
  StatsManager *statsManager;
  bool has_vlan_packets;
  struct ndpi_detection_module_struct *ndpi_struct;
  time_t last_pkt_rcvd, next_idle_flow_purge, next_idle_host_purge;
  bool running, is_idle;
  PacketDumper *pkt_dumper;
  PacketDumperTuntap *pkt_dumper_tap;
  u_char* antenna_mac;
  NetworkStats *networkStats;

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

  inline void setCPUAffinity(int core_id)      { cpu_affinity = core_id; };
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
  inline FlowHash *get_flows_hash()            { return flows_hash; }
  inline virtual bool is_ndpi_enabled()        { return(true); }
  inline u_int  getNumnDPIProtocols()          { return(ndpi_get_num_supported_protocols(ndpi_struct)); };
  inline time_t getTimeLastPktRcvd()           { return(last_pkt_rcvd); };
  inline void  setTimeLastPktRcvd(time_t t)    { last_pkt_rcvd = t; };
  inline char* get_ndpi_proto_name(u_int id)   { return(ndpi_get_proto_name(ndpi_struct, id));   };
  inline int   get_ndpi_proto_id(char *proto)  { return(ndpi_get_protocol_id(ndpi_struct, proto));   };
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
  inline bool  hasSeenVlanTaggedPackets()      { return(has_vlan_packets); }
  inline void  setSeenVlanTaggedPackets()      { has_vlan_packets = true; }
  inline struct ndpi_detection_module_struct* get_ndpi_struct() { return(ndpi_struct);         };
  inline bool is_sprobe_interface()            { return(sprobe_interface); };
  inline bool is_purge_idle_interface()        { return(purge_idle_flows_hosts);               };
  inline void enable_sprobe()                  { sprobe_interface = true; };
  int dumpFlow(time_t when, bool partial_dump, Flow *f);
  int dumpDBFlow(time_t when, bool partial_dump, Flow *f);
  int dumpEsFlow(time_t when, bool partial_dump, Flow *f);

  void resetSecondTraffic() { memset(currentMinuteTraffic, 0, sizeof(currentMinuteTraffic)); lastSecTraffic = 0, lastSecUpdate = 0;  };
  void updateSecondTraffic(time_t when);

  inline void incStats(time_t when, u_int16_t eth_proto, u_int16_t ndpi_proto,
		       u_int pkt_len, u_int num_pkts, u_int pkt_overhead) {
    ethStats.incStats(eth_proto, num_pkts, pkt_len, pkt_overhead);
    ndpiStats.incStats(ndpi_proto, 0, 0, 1, pkt_len);
    pktStats.incStats(pkt_len);
    if(lastSecUpdate == 0) lastSecUpdate = when; else if(lastSecUpdate != when) updateSecondTraffic(when);
  };
  inline EthStats* getStats()      { return(&ethStats);          };
  inline int get_datalink()        { return(pcap_datalink_type); };
  inline void set_datalink(int l)  { pcap_datalink_type = l;     };
  inline int isRunning()	   { return running;             };
  bool restoreHost(char *host_ip);
  u_int printAvailableInterfaces(bool printHelp, int idx, char *ifname, u_int ifname_len);
  void findFlowHosts(u_int16_t vlan_id,
		     u_int8_t src_mac[6], IpAddress *_src_ip, Host **src,
		     u_int8_t dst_mac[6], IpAddress *_dst_ip, Host **dst);
  Flow* findFlowByKey(u_int32_t key, patricia_tree_t *allowed_hosts);
  void findHostsByName(lua_State* vm, patricia_tree_t *allowed_hosts, char *key);
  bool dissectPacket(const struct pcap_pkthdr *h, const u_char *packet,
		     int *a_shaper_id, int *b_shaper_id, u_int16_t *ndpiProtocol);
  bool packetProcessing(const struct bpf_timeval *when,
			const u_int64_t time,
			struct ndpi_ethhdr *eth,
			u_int16_t vlan_id,
			struct ndpi_iphdr *iph,
			struct ndpi_ipv6hdr *ip6,
			u_int16_t ipsize, u_int16_t rawsize,
			const struct pcap_pkthdr *h,
			const u_char *packet,
			int *a_shaper_id,
			int *b_shaper_id,
			u_int16_t *ndpiProtocol);
  void flow_processing(ZMQ_Flow *zflow);
  void dumpFlows();
  void getnDPIStats(nDPIStats *stats);
  void updateFlowsL7Policy();
  void updateHostStats();
  virtual void lua(lua_State* vm);
  void getnDPIProtocols(lua_State *vm);
  int getActiveHostsList(lua_State* vm,
			 patricia_tree_t *allowed_hosts,
			 bool host_details, bool local_only,
			 char *sortColumn, u_int32_t maxHits,
			 u_int32_t toSkip, bool a2zSortOrder);
  void getFlowsStats(lua_State* vm);
  void getNetworksStats(lua_State* vm);
  int  getFlows(lua_State* vm, patricia_tree_t *allowed_hosts,
		Host *host, int ndpi_proto, bool local_only,
		char *sortColumn, u_int32_t maxHits,
		u_int32_t toSkip, bool a2zSortOrder);
  void getFlowPeersList(lua_State* vm, patricia_tree_t *allowed_hosts,
			char *numIP, u_int16_t vlanId);

  void purgeIdle(time_t when);
  u_int purgeIdleFlows();
  u_int purgeIdleHosts();

  inline u_int64_t getNumPackets()  { return(ethStats.getNumPackets());      };
  inline u_int64_t getNumBytes()    { return(ethStats.getNumBytes());        };
  u_int getNumFlows();
  u_int getNumHosts();
  u_int getNumHTTPHosts();

  void runHousekeepingTasks();
  Host* findHostByMac(u_int8_t mac[6], u_int16_t vlanId,
		      bool createIfNotPresent);
  Host* getHost(char *host_ip, u_int16_t vlan_id);
  bool getHostInfo(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool loadHostAlertPrefs(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool correlateHostActivity(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool similarHostActivity(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  void findUserFlows(lua_State *vm, char *username);
  void findPidFlows(lua_State *vm, u_int32_t pid);
  void findFatherPidFlows(lua_State *vm, u_int32_t pid);
  void findProcNameFlows(lua_State *vm, char *proc_name);
  void addAllAvailableInterfaces();
  inline bool idle() { return(is_idle); }
  inline u_int16_t getMTU() { return(ifMTU); }
  inline void setIdleState(bool new_state) { is_idle = new_state; }
  inline StatsManager *getStatsManager()   { return statsManager; }
  void listHTTPHosts(lua_State *vm, char *key);
#ifdef NTOPNG_PRO
  void refreshL7Rules();
  void refreshShapers();
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
  inline bool getDumpTrafficDiskPolicy()      { return(dump_to_disk);       }
  inline bool getDumpTrafficTapPolicy()       { return(dump_to_tap);        }
  inline u_int getDumpTrafficSamplingRate()   { return(dump_sampling_rate); }
  inline u_int getDumpTrafficMaxPktsPerFile() { return(dump_max_pkts_file); }
  inline u_int getDumpTrafficMaxSecPerFile()  { return(dump_max_duration);  }
  inline u_int getDumpTrafficMaxFiles()       { return(dump_max_files);     }
  inline char* getDumpTrafficTapName()        { return(pkt_dumper_tap ? pkt_dumper_tap->getName() : (char*)""); }
  void loadDumpPrefs();
  void getnDPIFlowsCount(lua_State *vm);

  Host* findHostsByIP(patricia_tree_t *allowed_hosts,
		      char *host_ip, u_int16_t vlan_id);
  inline void updateLocalStats(u_int num_pkts, u_int pkt_len, bool localsender, bool localreceiver) {
    localStats.incStats(num_pkts, pkt_len, localsender, localreceiver); }

  inline HostHash* get_hosts_hash()  { return(hosts_hash);       }
  inline bool is_bridge_interface()  { return(bridge_interface); }
  u_char* getAntennaMac()	     { return (antenna_mac);     }
  inline const char* getLocalIPAddresses() { return(ip_addresses.c_str()); }
  void addInterfaceAddress(char *addr);
  inline int exec_sql_query(lua_State *vm, char *sql) { return(db ? db->exec_sql_query(vm, sql) : -1); };
  NetworkStats* getNetworkStats(u_int8_t networkId);
  void allocateNetworkStats();
  void getsDPIStats(lua_State *vm);
  inline u_int64_t* getLastMinuteTrafficStats() { return((u_int64_t*)lastMinuteTraffic); }
#ifdef NTOPNG_PRO
  void updateFlowProfiles();
  inline FlowProfile* getFlowProfile(Flow *f)  { return(flow_profiles ? flow_profiles->getFlowProfile(f) : NULL);           }
  inline bool checkProfileSyntax(char *filter) { return(flow_profiles ? flow_profiles->checkProfileSyntax(filter) : false); }
#endif
};

#endif /* _NETWORK_INTERFACE_H_ */
