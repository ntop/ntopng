/*
 *
 * (C) 2013-19 - ntop.org
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

#ifndef _FLOW_H_
#define _FLOW_H_

#include "ntop_includes.h"

typedef struct {
  u_int32_t pktFrag;
} IPPacketStats;

typedef struct {
  u_int32_t pktRetr, pktOOO, pktLost, pktKeepAlive;
  u_int64_t last, next;
} TCPPacketStats;

typedef struct {
  u_int64_t last, next;
} TCPSeqNum;

typedef struct {
  u_int32_t cli2srv_packets, srv2cli_packets;
  u_int64_t cli2srv_bytes, srv2cli_bytes;
  u_int64_t cli2srv_goodput_bytes, srv2cli_goodput_bytes;
  TCPPacketStats tcp_stats_s2d, tcp_stats_d2s;
  ndpi_analyze_struct cli2srv_bytes_stats, srv2cli_bytes_stats;
} FlowTrafficStats;

class Flow : public GenericHashEntry {
 private:
  Host *cli_host, *srv_host;
  IpAddress *cli_ip_addr, *srv_ip_addr;
  ICMPinfo *icmp_info;
  u_int16_t cli_port, srv_port, vlanId;
  u_int32_t vrfId;
  u_int8_t protocol, src2dst_tcp_flags, dst2src_tcp_flags;
  u_int16_t alert_score;
  time_t performed_lua_calls[FLOW_LUA_CALL_MAX_VAL];
  struct ndpi_flow_struct *ndpiFlow;

  Bitmap status_map;              /* The bitmap of the possible problems on the flow */
  FlowStatus alerted_status;      /* This is the status which has triggered the alert */
  FlowStatus predominant_status;  /* This is the most important status currently set in the status_map */
  AlertType alert_type;
  AlertLevel alert_level;
  char *alert_status_info;        /* Alert specific status info */
  bool is_alerted;

  u_int hash_entry_id; /* Uniquely identify this Flow inside the flows_hash hash table */

  bool detection_completed, protocol_processed, fully_processed,
    cli2srv_direction, twh_over, twh_ok, dissect_next_http_packet, passVerdict,
    l7_protocol_guessed, flow_dropped_counts_increased,
    good_low_flow_detected, good_ssl_hs, update_flow_port_stats,
    quota_exceeded, has_malicious_cli_signature, has_malicious_srv_signature;
#ifdef ALERTED_FLOWS_DEBUG
  bool iface_alert_inc, iface_alert_dec;
#endif
  u_int16_t diff_num_http_requests;
#ifdef NTOPNG_PRO
  bool counted_in_aggregated_flow, status_counted_in_aggregated_flow;
  bool ingress2egress_direction;
  u_int8_t routing_table_id;
#ifndef HAVE_NEDGE
  FlowProfile *trafficProfile;
#else
  u_int16_t cli2srv_in, cli2srv_out, srv2cli_in, srv2cli_out;
  L7PolicySource_t cli_quota_source, srv_quota_source;
#endif
  CounterTrend throughputTrend, goodputTrend, thptRatioTrend;
#endif
  ndpi_protocol ndpiDetectedProtocol;
  custom_app_t custom_app;
  void *cli_id, *srv_id;
  json_object *json_info;
  ndpi_serializer *tlv_info;
  char *host_server_name, *bt_hash;
#ifdef HAVE_NEDGE
  u_int32_t last_conntrack_update; 
  u_int32_t marker;
#endif
  char *external_alert;
  bool trigger_scheduled_periodic_update, trigger_immediate_periodic_update;
 
  union {
    struct {
      char *last_url, *last_method;
      char *last_content_type;
      u_int16_t last_return_code;
    } http;

    struct {
      char *last_query;
      u_int16_t last_query_type;
      u_int16_t last_return_code;
      bool invalid_chars_in_query;
    } dns;

    struct {
      char *client_signature, *server_signature;
      struct {
	/* https://engineering.salesforce.com/open-sourcing-hassh-abed3ae5044c */
	char *client_hash, *server_hash;
      } hassh;
    } ssh;

    struct {
      u_int16_t ssl_version;
      char *certificate, *server_certificate;
      /* Certificate dissection */
      char *certificate_buf_leftover;
      u_int certificate_leftover;
      bool dissect_certificate;
      bool subject_alt_name_match;
      struct {
	/* https://engineering.salesforce.com/tls-fingerprinting-with-ja3-and-ja3s-247362855967 */
	char *client_hash, *server_hash;
	u_int16_t server_cipher;
	ndpi_cipher_weakness server_unsafe_cipher;
      } ja3;
    } ssl;

    struct {
      u_int8_t icmp_type, icmp_code;
      u_int16_t icmp_echo_id;
      u_int16_t max_icmp_payload_size;
    } icmp;
  } protos;

  struct {
    u_int32_t device_ip;
    u_int16_t in_index, out_index;
  } flow_device;

  /* eBPF Information */
  ParsedeBPF *cli_ebpf, *srv_ebpf;

  /* Stats */
  FlowTrafficStats stats;

  /* IP stats */
  IPPacketStats ip_stats_s2d, ip_stats_d2s;

  /* TCP stats */
  TCPSeqNum tcp_seq_s2d, tcp_seq_d2s;
  u_int16_t cli2srv_window, srv2cli_window;

  time_t doNotExpireBefore; /*
			      Used for collected flows via ZMQ to make sure that they are not immediately
			      expired if their last seen time is back in time with respect to ntopng
			    */
  struct timeval synTime, synAckTime, ackTime; /* network Latency (3-way handshake) */
  struct timeval clientNwLatency; /* The RTT/2 between the client and nprobe */
  struct timeval serverNwLatency; /* The RTT/2 between nprobe and the server */
  struct timeval c2sFirstGoodputTime;
  float rttSec, applLatencyMsec;

  InterarrivalStats *cli2srvPktTime, *srv2cliPktTime;
  
  /* Counter values at last host update */
  struct {
    FlowTrafficStats *partial;
    FlowTrafficStats delta;
    time_t first_seen, last_seen;
  } last_db_dump;

  /* Lazily initialized and used by a possible view interface */
  FlowTrafficStats *last_partial;

#ifdef HAVE_NEDGE
  struct {
    struct {
      TrafficShaper *ingress, *egress;
    } cli2srv;

    struct {
      TrafficShaper *ingress, *egress;
    } srv2cli;
  } flowShaperIds;
#endif
  struct timeval last_update_time;

  float bytes_thpt, goodput_bytes_thpt, top_bytes_thpt, top_goodput_bytes_thpt, top_pkts_thpt;
  float bytes_thpt_cli2srv, goodput_bytes_thpt_cli2srv;
  float bytes_thpt_srv2cli, goodput_bytes_thpt_srv2cli;
  float pkts_thpt, pkts_thpt_cli2srv, pkts_thpt_srv2cli;
  ValueTrend bytes_thpt_trend, goodput_bytes_thpt_trend, pkts_thpt_trend;
  //TimeSeries<float> *bytes_rate;
  u_int64_t cli2srv_last_packets, srv2cli_last_packets,
    prev_cli2srv_last_packets, prev_srv2cli_last_packets;
  u_int64_t cli2srv_last_bytes, srv2cli_last_bytes,
    cli2srv_last_goodput_bytes, srv2cli_last_goodput_bytes,
    prev_cli2srv_last_bytes, prev_srv2cli_last_bytes,
    prev_cli2srv_last_goodput_bytes, prev_srv2cli_last_goodput_bytes;

  //  tcpFlags = tp->th_flags, tcpSeqNum = ntohl(tp->th_seq), tcpAckNum = ntohl(tp->th_ack), tcpWin = ntohs(tp->th_win);
  char* intoaV4(unsigned int addr, char* buf, u_short bufLen);
  void allocDPIMemory();
  bool checkTor(char *hostname);
  void setBittorrentHash(char *hash);
  bool isLowGoodput() const;
  static void updatePacketStats(InterarrivalStats *stats, const struct timeval *when, bool update_iat);
  bool isReadyToBeMarkedAsIdle();
  inline bool isDeviceAllowedProtocol() const {
      return(!cli_host || !srv_host ||
        ((cli_host->getDeviceAllowedProtocolStatus(ndpiDetectedProtocol, true) == device_proto_allowed) &&
         (srv_host->getDeviceAllowedProtocolStatus(ndpiDetectedProtocol, false) == device_proto_allowed)));
  }
  char* printTCPflags(u_int8_t flags, char * const buf, u_int buf_len) const;
  inline bool isProto(u_int16_t p) const { return(((ndpiDetectedProtocol.master_protocol == p)
						   || (ndpiDetectedProtocol.app_protocol == p))
						  ? true : false); }
  void update_pools_stats(const struct timeval *tv,
			  u_int64_t diff_sent_packets, u_int64_t diff_sent_bytes,
			  u_int64_t diff_rcvd_packets, u_int64_t diff_rcvd_bytes);
  void periodic_dump_check(const struct timeval *tv);
  void updateCliJA3();
  void updateSrvJA3();
  void updateHASSH(bool as_client);
  const char* cipher_weakness2str(ndpi_cipher_weakness w) const;
  bool get_partial_traffic_stats(FlowTrafficStats **dst, FlowTrafficStats *delta, bool *first_partial) const;
  bool isLuaCallPerformed(FlowLuaCall flow_lua_call, const struct timeval *tv);
  void performLuaCall(FlowLuaCall flow_lua_call, const struct timeval *tv, periodic_ht_state_update_user_data_t *periodic_ht_state_update_user_data, bool quick);

 public:
  Flow(NetworkInterface *_iface,
       u_int16_t _vlanId, u_int8_t _protocol,
       Mac *_cli_mac, IpAddress *_cli_ip, u_int16_t _cli_port,
       Mac *_srv_mac, IpAddress *_srv_ip, u_int16_t _srv_port,
       const ICMPinfo * const icmp_info,
       time_t _first_seen, time_t _last_seen);
  ~Flow();

  inline Bitmap getStatusBitmap()     const     { return(status_map);           }
  inline void setStatus(FlowStatus status)      { status_map.setBit(status);    }
  inline void clearStatus(FlowStatus status)    { status_map.clearBit(status);  }
  bool triggerAlert(FlowStatus status, AlertType atype, AlertLevel severity, const char*alert_json);
  inline void setPredominantStatus(FlowStatus status) { predominant_status = status; }
  inline FlowStatus getPredominantStatus() const      { return(predominant_status); }
  inline const char* getStatusInfo() const      { return(alert_status_info);    }

  bool isBlacklistedFlow() const;
  struct site_categories* getFlowCategory(bool force_categorization);
  void freeDPIMemory();
  static const ndpi_protocol ndpiUnknownProtocol;
  bool isTiny() const;
  inline bool isSSL()  const { return(isProto(NDPI_PROTOCOL_TLS));  }
  inline bool isSSH()  const { return(isProto(NDPI_PROTOCOL_SSH));  }
  inline bool isDNS()  const { return(isProto(NDPI_PROTOCOL_DNS));  }
  inline bool isDHCP() const { return(isProto(NDPI_PROTOCOL_DHCP)); }
  inline bool isHTTP() const { return(isProto(NDPI_PROTOCOL_HTTP)); }
  inline bool isICMP() const { return(isProto(NDPI_PROTOCOL_IP_ICMP) || isProto(NDPI_PROTOCOL_IP_ICMPV6)); }
  inline bool isMaskedFlow() {
    return(!get_cli_host() || Utils::maskHost(get_cli_host()->isLocalHost())
	   || !get_srv_host() || Utils::maskHost(get_srv_host()->isLocalHost()));
  };
  char* serialize(bool es_json = false);
  json_object* flow2json();
  json_object* flow2es(json_object *flow_object);
  inline u_int8_t getTcpFlags()        const { return(src2dst_tcp_flags | dst2src_tcp_flags);  };
  inline u_int8_t getTcpFlagsCli2Srv() const { return(src2dst_tcp_flags);                      };
  inline u_int8_t getTcpFlagsSrv2Cli() const { return(dst2src_tcp_flags);                      };
#ifdef HAVE_NEDGE
  bool checkPassVerdict(const struct tm *now);
  bool isPassVerdict() const;
  inline void setConntrackMarker(u_int32_t marker) 	{ this->marker = marker; }
  inline u_int32_t getConntrackMarker() 		{ return(marker); }
#endif
  void setDropVerdict();
  void incFlowDroppedCounters();

  u_int32_t getPid(bool client);
  u_int32_t getFatherPid(bool client);
  u_int32_t get_uid(bool client) const;
  char* get_proc_name(bool client);
  char* get_user_name(bool client);
  u_int32_t getNextTcpSeq(u_int8_t tcpFlags, u_int32_t tcpSeqNum, u_int32_t payloadLen) ;
  static double toMs(const struct timeval *t);
  void timeval_diff(struct timeval *begin, const struct timeval *end, struct timeval *result, u_short divide_by_two);
  const char* getFlowInfo();
  inline char* getFlowServerInfo() {
    return (isSSL() && protos.ssl.certificate) ? protos.ssl.certificate : host_server_name;
  }
  inline char* getBitTorrentHash() { return(bt_hash);          };
  inline void  setBTHash(char *h)  { if(!h) return; if(bt_hash) free(bt_hash); bt_hash = h; }
  inline void  setServerName(char *v)  { if(host_server_name) free(host_server_name);  host_server_name = v; }
  void setTcpFlags(u_int8_t flags, bool src2dst_direction);
  void updateTcpFlags(const struct bpf_timeval *when,
		      u_int8_t flags, bool src2dst_direction);
  static void incTcpBadStats(bool src2dst_direction,
			     FlowTrafficStats *fts,
			     Host *cli, Host *srv,
			     u_int32_t ooo_pkts, u_int32_t retr_pkts,
			     u_int32_t lost_pkts, u_int32_t keep_alive_pkts);
  
  void updateTcpSeqNum(const struct bpf_timeval *when,
		       u_int32_t seq_num, u_int32_t ack_seq_num,
		       u_int16_t window, u_int8_t flags,
		       u_int16_t payload_len, bool src2dst_direction);

  void updateSeqNum(time_t when, u_int32_t sN, u_int32_t aN);
  void processDetectedProtocol();
  void processFullyDissectedProtocol();
  void setDetectedProtocol(ndpi_protocol proto_id, bool forceDetection);
  inline void setCustomApp(custom_app_t ca) {
    memcpy(&custom_app, &ca, sizeof(custom_app));
  };
  inline custom_app_t getCustomApp() const {
    return custom_app;
  };
  u_int16_t getStatsProtocol() const;
  void setJSONInfo(json_object *json);
  void setTLVInfo(ndpi_serializer *tlv);
#ifdef NTOPNG_PRO
  inline bool is_status_counted_in_aggregated_flow()    const { return(status_counted_in_aggregated_flow); };
  inline bool is_counted_in_aggregated_flow()           const { return(counted_in_aggregated_flow);        };
  inline void set_counted_in_aggregated_flow(bool val)        { counted_in_aggregated_flow  = val;         };
  inline void set_status_counted_in_aggregated_flow(bool val) { status_counted_in_aggregated_flow = val;   };
#endif
  void incStats(bool cli2srv_direction, u_int pkt_len,
		u_int8_t *payload, u_int payload_len, 
                u_int8_t l4_proto, u_int8_t is_fragment,
		u_int16_t tcp_flags, const struct timeval *when);
  void addFlowStats(bool cli2srv_direction, u_int in_pkts, u_int in_bytes, u_int in_goodput_bytes,
		    u_int out_pkts, u_int out_bytes, u_int out_goodput_bytes, 
		    u_int in_fragments, u_int out_fragments, time_t last_seen);
  inline bool isThreeWayHandshakeOK()    const { return(twh_ok);                          };
  inline bool isDetectionCompleted()     const { return(detection_completed);             };
  inline void* get_cli_id()              const { return(cli_id);                          };
  inline void* get_srv_id()              const { return(srv_id);                          };
  inline u_int32_t get_cli_ipv4()        const { return(cli_host->get_ip()->get_ipv4());  };
  inline u_int32_t get_srv_ipv4()        const { return(srv_host->get_ip()->get_ipv4());  };
  inline ndpi_protocol get_detected_protocol() const { return(isDetectionCompleted() ? ndpiDetectedProtocol : ndpiUnknownProtocol);          };
  inline struct ndpi_flow_struct* get_ndpi_flow()   const { return(ndpiFlow);                        };
  inline const struct ndpi_in6_addr* get_cli_ipv6() const { return(cli_host->get_ip()->get_ipv6());  };
  inline const struct ndpi_in6_addr* get_srv_ipv6() const { return(srv_host->get_ip()->get_ipv6());  };
  inline u_int16_t get_cli_port()        const { return(ntohs(cli_port));                 };
  inline u_int16_t get_srv_port()        const { return(ntohs(srv_port));                 };
  inline u_int16_t get_vlan_id()         const { return(vlanId);                          };
  inline u_int8_t  get_protocol()        const { return(protocol);                        };
  inline u_int64_t get_bytes()           const { return(stats.cli2srv_bytes+stats.srv2cli_bytes);     };
  inline u_int64_t get_bytes_cli2srv()   const { return(stats.cli2srv_bytes);                   };
  inline u_int64_t get_bytes_srv2cli()   const { return(stats.srv2cli_bytes);                   };
  inline u_int64_t get_goodput_bytes()   const { return(stats.cli2srv_goodput_bytes+stats.srv2cli_goodput_bytes);     };
  inline u_int64_t get_packets()         const { return(stats.cli2srv_packets+stats.srv2cli_packets); };
  inline u_int64_t get_packets_cli2srv() const { return(stats.cli2srv_packets);                 };
  inline u_int64_t get_packets_srv2cli() const { return(stats.srv2cli_packets);                 };
  inline u_int64_t get_partial_bytes()           const { return get_partial_bytes_cli2srv() + get_partial_bytes_srv2cli();     };
  inline u_int64_t get_partial_packets()         const { return get_partial_packets_cli2srv() + get_partial_packets_srv2cli(); };
  inline u_int64_t get_partial_goodput_bytes()   const { return last_db_dump.delta.cli2srv_goodput_bytes + last_db_dump.delta.srv2cli_goodput_bytes;       };
  inline u_int64_t get_partial_bytes_cli2srv()   const { return last_db_dump.delta.cli2srv_bytes;   };
  inline u_int64_t get_partial_bytes_srv2cli()   const { return last_db_dump.delta.srv2cli_bytes;   };
  inline u_int64_t get_partial_packets_cli2srv() const { return last_db_dump.delta.cli2srv_packets; };
  inline u_int64_t get_partial_packets_srv2cli() const { return last_db_dump.delta.srv2cli_packets; };
  bool needsExtraDissection();
  bool hasDissectedTooManyPackets();
  bool get_partial_traffic_stats_view(FlowTrafficStats *delta, bool *first_partial);
  inline FlowTrafficStats * getFlowTrafficStats() { return &stats; };
  bool update_partial_traffic_stats_db_dump();
  inline float get_bytes_thpt()          const { return(bytes_thpt);                      };
  inline float get_goodput_bytes_thpt()  const { return(goodput_bytes_thpt);              };
  inline time_t get_partial_first_seen() const { return(last_db_dump.first_seen); };
  inline time_t get_partial_last_seen()  const { return(last_db_dump.last_seen);  };
  inline u_int32_t get_duration()        const { return((u_int32_t)(get_last_seen() - get_first_seen())); };
  inline char* get_protocol_name()       const { return(Utils::l4proto2name(protocol));   };
  inline Host* get_cli_host()               const { return(cli_host);    };
  inline Host* get_srv_host()               const { return(srv_host);    };
  inline const IpAddress* get_cli_ip_addr() const { return(cli_ip_addr); };
  inline const IpAddress* get_srv_ip_addr() const { return(srv_ip_addr); };
  inline json_object* get_json_info()	    const  { return(json_info);                       };
  inline ndpi_serializer* get_tlv_info()	    const  { return(tlv_info);                       };
  inline void setICMPPayloadSize(u_int16_t size)     { if(isICMP()) protos.icmp.max_icmp_payload_size = max(protos.icmp.max_icmp_payload_size, size); };
  inline u_int16_t getICMPPayloadSize()             const { return(isICMP() ? protos.icmp.max_icmp_payload_size : 0); };
  inline ICMPinfo* getICMPInfo()                    const { return(isICMP() ? icmp_info : NULL); }
  inline ndpi_protocol_breed_t get_protocol_breed() const {
    return(ndpi_get_proto_breed(iface->get_ndpi_struct(), isDetectionCompleted() ? ndpiDetectedProtocol.app_protocol : NDPI_PROTOCOL_UNKNOWN));
  };
  inline const char * const get_protocol_breed_name() const {
    return(ndpi_get_proto_breed_name(iface->get_ndpi_struct(), get_protocol_breed()));
  };
  inline ndpi_protocol_category_t get_protocol_category() const {
    return(ndpi_get_proto_category(iface->get_ndpi_struct(),
				   isDetectionCompleted() ? ndpiDetectedProtocol : ndpiUnknownProtocol));
};
  inline const char * const get_protocol_category_name() const {
    return(ndpi_category_get_name(iface->get_ndpi_struct(), get_protocol_category()));
  };
  char* get_detected_protocol_name(char *buf, u_int buf_len) const {
    return(ndpi_protocol2name(iface->get_ndpi_struct(),
			      isDetectionCompleted() ? ndpiDetectedProtocol : ndpiUnknownProtocol,
			      buf, buf_len));
  }
  static inline ndpi_protocol get_ndpi_unknown_protocol() { return ndpiUnknownProtocol; };

  u_int32_t get_packetsLost();
  u_int32_t get_packetsRetr();
  u_int32_t get_packetsOOO();

  u_int64_t get_current_bytes_cli2srv() const;
  u_int64_t get_current_bytes_srv2cli() const;
  u_int64_t get_current_goodput_bytes_cli2srv() const;
  u_int64_t get_current_goodput_bytes_srv2cli() const;
  u_int64_t get_current_packets_cli2srv() const;
  u_int64_t get_current_packets_srv2cli() const;

  /* Methods to handle the flow in-memory lifecycle */
  void set_hash_entry_state_idle();
  bool is_hash_entry_state_idle_transition_ready() const;
  void periodic_hash_entry_state_update(void *user_data, bool quick);
  void periodic_stats_update(void *user_data, bool quick);
  void  set_hash_entry_id(u_int assigned_hash_entry_id);
  u_int get_hash_entry_id() const;

  char* print(char *buf, u_int buf_len) const;
    
  u_int32_t key();
  static u_int32_t key(Host *cli, u_int16_t cli_port,
		       Host *srv, u_int16_t srv_port,
		       u_int16_t vlan_id,
		       u_int16_t protocol);
  void lua(lua_State* vm, AddressTree * ptree, DetailsLevel details_level, bool asListElement);
  void lua_get_min_info(lua_State* vm);
  void lua_get_tcp_packet_issues(lua_State* vm);
  void lua_duration_info(lua_State* vm);
  void lua_device_protocol_allowed_info(lua_State *vm);
  void lua_get_icmp_info(lua_State *vm) const;
  void lua_get_tcp_stats(lua_State *vm) const;

  void lua_get_unicast_info(lua_State* vm) const;
  void lua_get_status(lua_State* vm) const;
  void lua_get_protocols(lua_State* vm) const;
  void lua_get_bytes(lua_State* vm) const;
  void lua_get_dir_traffic(lua_State* vm, bool cli2srv) const;
  void lua_get_dir_iat(lua_State* vm, bool cli2srv) const;
  void lua_get_packets(lua_State* vm) const;
  void lua_get_throughput(lua_State* vm) const;
  void lua_get_time(lua_State* vm) const;
  void lua_get_ip(lua_State *vm, bool client) const;
  void lua_get_info(lua_State *vm, bool client) const;
  void lua_get_ssl_info(lua_State *vm) const;
  void lua_get_ssh_info(lua_State *vm) const;
  void lua_get_http_info(lua_State *vm) const;
  void lua_get_dns_info(lua_State *vm) const;
  void lua_get_tcp_info(lua_State *vm) const;
  void lua_get_port(lua_State *vm, bool client) const;
  void lua_get_geoloc(lua_State *vm, bool client, bool coords, bool country_city) const;

  bool equal(const IpAddress *_cli_ip, const IpAddress *_srv_ip,
	     u_int16_t _cli_port, u_int16_t _srv_port,
	     u_int16_t _vlanId, u_int8_t _protocol,
	     const ICMPinfo * const icmp_info,
	     bool *src2srv_direction) const;
  void sumStats(nDPIStats *ndpi_stats, FlowStats *stats);
  bool dumpFlow(const struct timeval *tv, NetworkInterface *dumper);
  bool match(AddressTree *ptree);
  void dissectHTTP(bool src2dst_direction, char *payload, u_int16_t payload_len);
  void dissectSSL(char *payload, u_int16_t payload_len);
  void dissectSSDP(bool src2dst_direction, char *payload, u_int16_t payload_len);
  void dissectMDNS(u_int8_t *payload, u_int16_t payload_len);
  void dissectBittorrent(char *payload, u_int16_t payload_len);
  void updateInterfaceLocalStats(bool src2dst_direction, u_int num_pkts, u_int pkt_len);
  void fillZmqFlowCategory();
  inline void setICMP(bool src2dst_direction, u_int8_t icmp_type, u_int8_t icmp_code, u_int8_t *icmpdata) {
    if(isICMP()) {
      protos.icmp.icmp_type = icmp_type, protos.icmp.icmp_code = icmp_code;
      if(get_cli_host()) get_cli_host()->incICMP(icmp_type, icmp_code, src2dst_direction ? true : false, get_srv_host());
      if(get_srv_host()) get_srv_host()->incICMP(icmp_type, icmp_code, src2dst_direction ? false : true, get_cli_host());
      protos.icmp.icmp_echo_id = ntohs(*((u_int16_t*)&icmpdata[4]));
    }
  }
  inline void getICMP(u_int8_t *_icmp_type, u_int8_t *_icmp_code, u_int16_t *_icmp_echo_id) {
    *_icmp_type = protos.icmp.icmp_type, *_icmp_code = protos.icmp.icmp_code, *_icmp_echo_id = protos.icmp.icmp_echo_id;
  }
  inline char* getDNSQuery()        { return(isDNS() ? protos.dns.last_query : (char*)"");  }
  inline void  setDNSQuery(char *v) { if(isDNS()) { if(protos.dns.last_query) free(protos.dns.last_query);  protos.dns.last_query = v; } }
  inline void  setDNSQueryType(u_int16_t t) { if(isDNS()) { protos.dns.last_query_type = t; } }
  inline void  setDNSRetCode(u_int16_t c) { if(isDNS()) { protos.dns.last_return_code = c; } }
  inline u_int16_t getLastQueryType() { return(isDNS() ? protos.dns.last_query_type : 0); }
  inline u_int16_t getDNSRetCode()  { return(isDNS() ? protos.dns.last_return_code : 0); }
  inline bool  isDNSQuery()         { return(isDNS() && ndpiFlow && ndpiFlow->protos.dns.is_query); }
  inline char* getHTTPURL()         { return(isHTTP() ? protos.http.last_url : (char*)"");   }
  inline void  setHTTPURL(char *v)  { if(isHTTP()) { if(protos.http.last_url) free(protos.http.last_url);  protos.http.last_url = v; } }
  inline void  setHTTPMethod(char *v)  { if(isHTTP()) { if(protos.http.last_method) free(protos.http.last_method);  protos.http.last_method = v; } }
  inline void  setHTTPRetCode(u_int16_t c) { if(isHTTP()) { protos.http.last_return_code = c; } }
  inline char* getHTTPContentType() { return(isHTTP() ? protos.http.last_content_type : (char*)"");   }
  inline char* getSSLCertificate()  { return(isSSL() ? protos.ssl.certificate : (char*)""); }
  bool isSSLProto();

  void setExternalAlert(json_object *a);
  void luaRetrieveExternalAlert(lua_State *vm);
  u_int32_t getSrvTcpIssues();
  u_int32_t getCliTcpIssues();

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  inline void updateProfile()     { trafficProfile = iface->getFlowProfile(this); }
  inline char* get_profile_name() { return(trafficProfile ? trafficProfile->getName() : (char*)"");}
#endif
  /* http://bradhedlund.com/2008/12/19/how-to-calculate-tcp-throughput-for-long-distance-links/ */
  inline float getCli2SrvMaxThpt() const { return(rttSec ? ((float)(cli2srv_window*8)/rttSec) : 0); }
  inline float getSrv2CliMaxThpt() const { return(rttSec ? ((float)(srv2cli_window*8)/rttSec) : 0); }

  inline InterarrivalStats* getCli2SrvIATStats() const { return cli2srvPktTime; }
  inline InterarrivalStats* getSrv2CliIATStats() const { return srv2cliPktTime; }

  inline bool hasTCP3WHSCompleted() const { return (((src2dst_tcp_flags & (TH_SYN | TH_ACK)) == (TH_SYN | TH_ACK))
						    && ((dst2src_tcp_flags & (TH_SYN | TH_ACK)) == (TH_SYN | TH_ACK))); }
  inline bool isTCPEstablished() const { return (!isTCPClosed() && !isTCPReset() && hasTCP3WHSCompleted()); }
  inline bool isTCPConnecting()  const { return (src2dst_tcp_flags == TH_SYN
						 && (!dst2src_tcp_flags || (dst2src_tcp_flags == (TH_SYN | TH_ACK)))); }
  inline bool isTCPClosed()      const { return (((src2dst_tcp_flags & (TH_SYN | TH_ACK | TH_FIN)) == (TH_SYN | TH_ACK | TH_FIN))
						 && ((dst2src_tcp_flags & (TH_SYN | TH_ACK | TH_FIN)) == (TH_SYN | TH_ACK | TH_FIN))); }
  inline bool isTCPReset()       const { return (!isTCPClosed()
						 && ((src2dst_tcp_flags & TH_RST) || (dst2src_tcp_flags & TH_RST))); }
  inline bool isFlowAlerted() const         { return(is_alerted); };
  inline void      setVRFid(u_int32_t v)  { vrfId = v;                              }

  inline void setFlowNwLatency(const struct timeval * const tv, bool client) {
    if(client) {
      memcpy(&clientNwLatency, tv, sizeof(*tv));
      if(cli_host) cli_host->updateRoundTripTime(Utils::timeval2ms(&clientNwLatency));
    } else {
      memcpy(&serverNwLatency, tv, sizeof(*tv));
      if(srv_host) srv_host->updateRoundTripTime(Utils::timeval2ms(&serverNwLatency));
    }
  }
  inline void setRtt() {
    rttSec = ((float)(serverNwLatency.tv_sec + clientNwLatency.tv_sec))
      +((float)(serverNwLatency.tv_usec + clientNwLatency.tv_usec)) / (float)1000000;
  }
  inline void setFlowApplLatency(float latency_msecs) { applLatencyMsec = latency_msecs; }
  inline bool      setFlowDevice(u_int32_t device_ip, u_int16_t inidx, u_int16_t outidx) {
    if((flow_device.device_ip > 0 && flow_device.device_ip != device_ip)
       || (flow_device.in_index > 0 && flow_device.in_index != inidx)
       || (flow_device.out_index > 0 && flow_device.out_index != outidx))
      return false;
    if(device_ip) flow_device.device_ip = device_ip;
    if(inidx)     flow_device.in_index = inidx;
    if(outidx)    flow_device.out_index = outidx;
    return true;
  }
  inline u_int32_t getFlowDeviceIp()       { return flow_device.device_ip; };
  inline u_int16_t getFlowDeviceInIndex()  { return flow_device.in_index;  };
  inline u_int16_t getFlowDeviceOutIndex() { return flow_device.out_index; };

  inline void setScore(u_int16_t score)    { alert_score = score; };
  inline u_int16_t getScore()              { return(alert_score); };
  inline bool isTwhOver()                  { return(twh_over); };

#ifdef HAVE_NEDGE
  inline void setLastConntrackUpdate(u_int32_t when) { last_conntrack_update = when; }
  bool isNetfilterIdleFlow() const;

  void setPacketsBytes(time_t now, u_int32_t s2d_pkts, u_int32_t d2s_pkts, u_int64_t s2d_bytes, u_int64_t d2s_bytes);  
  void getFlowShapers(bool src2dst_direction, TrafficShaper **shaper_ingress, TrafficShaper **shaper_egress) {
    if(src2dst_direction) {
      *shaper_ingress = flowShaperIds.cli2srv.ingress,
	*shaper_egress = flowShaperIds.cli2srv.egress;
    } else {
      *shaper_ingress = flowShaperIds.srv2cli.ingress,
	*shaper_egress = flowShaperIds.srv2cli.egress;
    }
  }
  bool updateDirectionShapers(bool src2dst_direction, TrafficShaper **ingress_shaper, TrafficShaper **egress_shaper);
  void updateFlowShapers(bool first_update=false);
  void recheckQuota(const struct tm *now);
  inline u_int8_t getFlowRoutingTableId() { return(routing_table_id); }
  inline void setIngress2EgressDirection(bool _ingress2egress) { ingress2egress_direction = _ingress2egress; }
  inline bool isIngress2EgressDirection() { return(ingress2egress_direction); }
#endif
  void housekeep(time_t t);
  void postFlowSetIdle(const struct timeval *tv, bool quick);
  void setParsedeBPFInfo(const ParsedeBPF * const ebpf, bool src2dst_direction);
  inline const ContainerInfo* getClientContainerInfo() const {
    return cli_ebpf && cli_ebpf->container_info_set ? &cli_ebpf->container_info : NULL;
  }
  inline const ContainerInfo* getServerContainerInfo() const {
    return srv_ebpf && srv_ebpf->container_info_set ? &srv_ebpf->container_info : NULL;
  }
  inline const ProcessInfo * getClientProcessInfo() const {
    return cli_ebpf && cli_ebpf->process_info_set ? &cli_ebpf->process_info : NULL;
  }
  inline const ProcessInfo* getServerProcessInfo() const {
    return srv_ebpf && srv_ebpf->process_info_set ? &srv_ebpf->process_info : NULL;
  }
  inline const TcpInfo* getClientTcpInfo() const {
    return cli_ebpf && cli_ebpf->tcp_info_set ? &cli_ebpf->tcp_info : NULL;
  }
  inline const TcpInfo* getServerTcpInfo() const {
    return srv_ebpf && srv_ebpf->tcp_info_set ? &srv_ebpf->tcp_info : NULL;
  }

  inline bool isNotPurged() {
    return(getInterface()->isPacketInterface() && getInterface()->is_purge_idle_interface()
     && !idle() && isIdle(10 * getInterface()->getFlowMaxIdle()));
  }

  inline u_int16_t getSSLVersion()  { return(isSSL() ? (protos.ssl.ssl_version) : 0); }
};

#endif /* _FLOW_H_ */
